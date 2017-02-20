/*
 * Copyright (c) Bosch Software Innovations GmbH 2016.
 * Copyright Siemens AG, 2016.
 * Part of the SW360 Portal Project.
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 */
package org.eclipse.sw360.cvesearch.datasource.heuristics;

import org.eclipse.sw360.cvesearch.datasource.CveSearchApi;
import org.eclipse.sw360.cvesearch.datasource.CveSearchGuesser;
import org.eclipse.sw360.cvesearch.datasource.matcher.Match;
import org.eclipse.sw360.datahandler.thrift.components.Release;
import org.apache.log4j.Logger;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.function.Function;
import java.util.function.Predicate;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import static org.eclipse.sw360.datahandler.common.CommonUtils.nullToEmptyString;
import static java.util.Collections.*;

public class SearchLevels {

    private static final String CPE_WILDCARD      = ".*";
    private static final String CPE_NEEDLE_PREFIX = "cpe:2.3:.:";

    private Logger log = Logger.getLogger(SearchLevels.class);

    private List<SearchLevel> searchLevels;

    public class NeedleWithMeta {
        public String needle;
        public String description;
        public NeedleWithMeta(String needle, String description){
            this.needle = needle;
            this.description = description;
        }
    }

    @FunctionalInterface
    public interface SearchLevel {
        List<NeedleWithMeta> apply(Release release) throws IOException;
    }

    public SearchLevels(CveSearchApi cveSearchApi, int vendorThreshold, int productThreshold, int cutoff) {
        searchLevels = new ArrayList<>();

        // Level 1. search by full cpe
        addCPESearchLevel();
        // Level 2. and 3.
        addGuessingSearchLevels(cveSearchApi, vendorThreshold, productThreshold, cutoff);
    }

    public Stream<List<NeedleWithMeta>> apply(Release release) throws IOException {
        try {
        return searchLevels.stream()
                .map(searchLevel -> {
                    try {
                        return searchLevel.apply(release);
                    } catch (IOException e) {
                        throw new UncheckedIOException(e);
                    }
                }) ;
        } catch (UncheckedIOException ue) {
            throw ue.getIOExceptionCause();
        }
    }

    class UncheckedIOException extends RuntimeException{
        UncheckedIOException(IOException e) {
            super(e);
        }

        IOException getIOExceptionCause(){
            return (IOException) getCause();
        }
    }

    //==================================================================================================================
    private void addCPESearchLevel() {
        Predicate<Release> isPossible = r -> r.isSetCpeid() && isCpe(r.getCpeid().toLowerCase());
        searchLevels.add(r -> {
            if(isPossible.test(r)){
                return singletonList(new NeedleWithMeta(r.getCpeid().toLowerCase(), "CPE"));
            }
            return EMPTY_LIST;
        });
    }

    private void addGuessingSearchLevels(CveSearchApi cveSearchApi, int vendorThreshold, int productThreshold, int cutoff) {
        CveSearchGuesser cveSearchGuesser = new CveSearchGuesser(cveSearchApi);
        cveSearchGuesser.setVendorThreshold(vendorThreshold);
        cveSearchGuesser.setProductThreshold(productThreshold);
        cveSearchGuesser.setCutoff(cutoff);

        // Level 2. search by guessed vendors and products with version
        searchLevels.add(release -> guessForRelease(cveSearchGuesser, release, true));

        // Level 3. search by guessed vendors and products without version
        searchLevels.add(release -> guessForRelease(cveSearchGuesser, release, false));
    }


    protected List<NeedleWithMeta> guessForRelease(CveSearchGuesser cveSearchGuesser, Release release, boolean useVersionInformation) throws IOException {
        if(useVersionInformation && !release.isSetVersion()){
            return EMPTY_LIST;
        }

        List<Match> vendorProductList;

        String productHaystack = release.getName();
        if (release.isSetVendor() &&
                (release.getVendor().isSetShortname() || release.getVendor().isSetFullname())) {
            String vendorHaystack = nullToEmptyString(release.getVendor().getShortname()) + " " +
                    nullToEmptyString(release.getVendor().getFullname());
            vendorProductList = cveSearchGuesser.guessVendorAndProducts(vendorHaystack, productHaystack);
        } else {
            vendorProductList = cveSearchGuesser.guessVendorAndProducts(productHaystack);
        }

        String cpeNeedlePostfix = ":" + (useVersionInformation ? release.getVersion() : "") + ".*";
        Function<String,String> cpeBuilder = cpeNeedle -> CPE_NEEDLE_PREFIX + cpeNeedle + cpeNeedlePostfix;

        return vendorProductList.stream()
                .map(match -> new NeedleWithMeta(cpeBuilder.apply(match.getNeedle()),
                        "heuristic (dist. " + (useVersionInformation ? "0" : "1") + match.getDistance() + ")"))
                .collect(Collectors.toList());
    }

    //==================================================================================================================
    protected Function<Release,String> escapeGeneratorResult(Function<Release,String> generator) {
        return r -> generator.apply(r)
                .replace('/','.')
                .replace('\\','.')
                .replace('*','.')
                .replace('+','.')
                .replace('!','.')
                .replace('?','.')
                .replace('^','.')
                .replace('$','.')
                .replace('[','.')
                .replace(']','.')
                .replace(" ", CPE_WILDCARD)
                .toLowerCase();
    }

    protected Function<Release, String> implodeSearchNeedleGenerators(Function<Release,String> generator, Function<Release,String> ... generators){
        return Arrays.stream(generators)
                .map(this::escapeGeneratorResult)
                .reduce(generator,
                        (g1,g2) -> r -> g1.apply(r) + CPE_WILDCARD + g2.apply(r));
    }

    protected boolean isCpe(String potentialCpe){
        return (! (null == potentialCpe))
                && potentialCpe.startsWith("cpe:")
                && potentialCpe.length() > 10;
    }
}
