/*
 * Copyright Siemens AG, 2016. Part of the SW360 Portal Project.
 *
 * SPDX-License-Identifier: EPL-1.0
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 */
include "sw360.thrift"
include "users.thrift"

namespace java org.eclipse.sw360.datahandler.thrift.vulnerabilities
namespace php sw360.thrift.vulnerabilities

typedef sw360.RequestSummary RequestSummary
typedef users.User User
typedef sw360.RequestStatus RequestStatus
typedef sw360.VerificationStateInfo VerificationStateInfo

struct ReleaseVulnerabilityRelation{
    // Basic information
    1: optional string id,
    2: optional string revision,
    3: optional string type = "releasevulnerabilityrelation",

    // Additional information
    10: required string releaseId,
    11: required string vulnerabilityId,
    12: optional list<VerificationStateInfo> verificationStateInfo,

    // meta information
   100: optional string matchedBy,
   101: optional string usedNeedle,
}

struct Vulnerability{
    // General information
    1: optional string id,
    2: optional string revision,
    3: optional string type = "vulnerability",
    4: optional string lastUpdateDate,

    // Additional information
    10: required string externalId,
    11: optional string title,
    12: optional string description,
    13: optional string publishDate,
    14: optional string lastExternalUpdate,
    15: optional string priority,
    16: optional string priorityText,
    17: optional string action,
    19: optional map<string, string> impact,
    20: optional string legalNotice,
    21: optional set<string> assignedExtComponentIds,
    22: optional set<CVEReference> cveReferences,
    23: optional set<VendorAdvisory> vendorAdvisories,
    24: optional string extendedDescription,
    25: optional set<string> references,

    //additional from CVE earch data
    30: optional double cvss,
    31: optional bool isSetCvss,
    32: optional string cvssTime,
    33: optional map<string,string> vulnerableConfiguration,
    34: optional map<string,string> access,
    35: optional string cwe,
    36: optional map<string, map<string, string>> cveFurtherMetaDataPerSource;
}

struct VulnerabilityDTO{
    // WILL NOT BE SAVED IN DB, only for view
    // General information
    1: optional string id,
    2: optional string revision,
    3: optional string type = "vulnerabilitydto",

    // Additional information
    10: required string externalId,
    11: optional string title,
    12: optional string description,
    13: optional string publishDate,
    14: optional string lastExternalUpdate,
    15: optional string priority,
    16: optional string priorityToolTip,
    17: optional string action,
    19: optional map<string,string> impact,
    20: optional string legalNotice,
    22: optional set<CVEReference> cveReferences,
    25: optional set<string> references,

    // additional DTO fields
    31: optional string intReleaseId
    32: optional string intReleaseName
    33: optional string intComponentId
    34: optional string intComponentName
    35: optional ReleaseVulnerabilityRelation releaseVulnerabilityRelation

    // meta information
   100: optional string matchedBy,
   101: optional string usedNeedle,
}

struct CVEReference{
    // Basic information
    1: optional string id,
    2: optional string revision,
    3: optional string type = "cveReference",

    // Additional information
    10: required string year,
    11: required string number,
}

struct VendorAdvisory{
    // Basic information
    1: optional string id,
    2: optional string revision,
    3: optional string type = "vendoradvisory",

    // Additional information
    10: required string vendor,
    11: required string name,
    12: required string url
}

enum VulnerabilityRatingForProject {
    NOT_CHECKED = 0,
    IRRELEVANT = 1,
    RESOLVED = 2,
    APPLICABLE = 3,
}

struct VulnerabilityCheckStatus{
    1: required string checkedOn,
    2: required string checkedBy,
    3: optional string comment,
    4: required VulnerabilityRatingForProject vulnerabilityRating,
}

struct ProjectVulnerabilityRating{

    1: optional string id,
    2: optional string revision,
    3: optional string type = "projectvulnerabilityrating",

    4: required string projectId,
    //first key: externalIds of the vulnerabilities, second key: releaseId (couchDb id)
    5: required map<string, map<string, list<VulnerabilityCheckStatus>>> vulnerabilityIdToReleaseIdToStatus,
}

struct VulnerabilityWithReleaseRelations{
    1: required Vulnerability vulnerability,
    2: required list<ReleaseVulnerabilityRelation> releaseRelation
}

service VulnerabilityService {
    // General information
     /**
       * returns a list with all vulnerabilites in the SW360 database if the user is valid
       * returns empty list if user is not valid
       **/
    list<Vulnerability> getVulnerabilities(1: User user);

     /**
       * returns a list with the latest vulnerabilites in the SW360 database if the user is valid
       * returns empty list if user is not valid, or if the limit is smaller than zero
       **/
    list<Vulnerability> getLatestVulnerabilities(1: User user, 2: i32 limit = 20);

    /**
      * Returns the total number of vulnerabilites in the database
      **/
    i32 getTotalVulnerabilityCount(1: User user);

    /**
      * if the user is valid: returns a list with all vulnerability linked to the release with id releaseId as DTOs
      * returns empty list if user is not valid
      **/
    list<VulnerabilityDTO> getVulnerabilitiesByReleaseId(1: string releaseId, 2: User user);

    /**
      * see getVulnerabilitiesByReleaseId for all releases that belong to the component with componentId
      **/
    list<VulnerabilityDTO> getVulnerabilitiesByComponentId(1: string componentId, 2: User user);

     /**
       * see getVulnerabilitiesByReleaseId for all releases that are directly linked to the project with projectId
       **/
    list<VulnerabilityDTO> getVulnerabilitiesByProjectId(1: string projectId, 2: User user);

     /**
       * see getVulnerabilitiesByReleaseId, but except vulnerabilities marked as incorrect for that release
       **/
    list<VulnerabilityDTO> getVulnerabilitiesByReleaseIdWithoutIncorrect(1: string releaseId, 2: User user);

    /**
      * see getVulnerabilitiesByComponentId, but except vulnerabilities marked as incorrect for the respective release
      **/
    list<VulnerabilityDTO> getVulnerabilitiesByComponentIdWithoutIncorrect(1: string componentId, 2: User user);

    /**
      * see getVulnerabilitiesByProjectId, but except vulnerabilities marked as incorrect for the respective release
      **/
    list<VulnerabilityDTO> getVulnerabilitiesByProjectIdWithoutIncorrect(1: string projectId, 2: User user);

   /**
     * returns list with one ProjectVulnerabilityRating for given projectId
     * returns emptyList if none is found
     **/
    list<ProjectVulnerabilityRating> getProjectVulnerabilityRatingByProjectId(1: string projectId, 2: User user);

   /**
     * updates the link in the database if user is allowed to edit corresponding project and returns SUCCESS
     * if user is not allowed to edit project - FAILURE is returned
     **/
    RequestStatus updateProjectVulnerabilityRating(1: ProjectVulnerabilityRating link, 2: User user);

   /**
     * updates the relation in the database if user is ADMIN, returns SUCCESS
     * if user is not ADMIN - FAILURE is returned
     **/
    RequestStatus updateReleaseVulnerabilityRelation(1: ReleaseVulnerabilityRelation relation, 2: User user);

   /**
     * returns ReleaseVulnerabilityRelation with vulnerabilityId and releaseId as given (if present in db) for a valid user
     * returns null if user is not valid
     */
    ReleaseVulnerabilityRelation getRelationByIds(1: string releaseId, 2: string vulnerabilityId, 3: User user);

    /**
      * returns the vulnerability with given externalId if it exists in the database and if user is valid
      * returns null otherwise
      **/
    Vulnerability getVulnerabilityByExternalId(1: string externalId, 2: User user);

    /**
      * returns the vulnerability with given externalId if it exists in the database and if user is valid
      * returns null otherwise
      **/
    list<Vulnerability> getVulnerabilitiesByExternalIdOrConfiguration(1: optional string externalId, 2: optional string vulnerableConfiguration, 3: User user);

    /**
      * returns the vulnerability with given externalId if it exists in the database and if user is valid
      * returns null otherwise
      **/
    VulnerabilityWithReleaseRelations getVulnerabilityWithReleaseRelationsByExternalId(1: string externalId, 2: User user);
}
