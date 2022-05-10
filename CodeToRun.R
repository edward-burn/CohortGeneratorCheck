sessionInfo()
Sys.setlocale("LC_ALL","English")

renv::activate()
renv::restore()

library(here)
library(RSQLite)
library(DatabaseConnector)
library(Eunomia)
library(CirceR)
library(CohortGenerator)

# First construct a cohort definition set: an empty 
# data frame with the cohorts to generate
cohortsToCreate <- CohortGenerator::createEmptyCohortDefinitionSet()

# Fill the cohort set using  cohorts included in this 
# package as an example
# cohortJsonFiles <- list.files(path = system.file("testdata/name/cohorts", package = "CohortGenerator"), full.names = TRUE)
cohortJsonFiles <- list.files(path = here::here("cohorts"), full.names = TRUE)
  
for (i in 1:length(cohortJsonFiles)) {
  cohortJsonFileName <- cohortJsonFiles[i]
  cohortName <- tools::file_path_sans_ext(basename(cohortJsonFileName))
  # Here we read in the JSON in order to create the SQL
  # using [CirceR](https://ohdsi.github.io/CirceR/)
  # If you have your JSON and SQL stored differenly, you can
  # modify this to read your JSON/SQL files however you require
  cohortJson <- readChar(cohortJsonFileName, file.info(cohortJsonFileName)$size)
  cohortExpression <- CirceR::cohortExpressionFromJson(cohortJson)
  cohortSql <- CirceR::buildCohortQuery(cohortExpression, options = CirceR::createGenerateOptions(generateStats = TRUE))
  SqlRender::writeSql(sql = cohortSql, targetFile = paste0(cohortName, ".sql"))
  #uncommenting the below two line fixes the problem
   # cohortSql <- stringr::str_replace(cohortSql, "10000,0000", "10000.0000")
   # cohortSql <- stringr::str_replace(cohortSql,"150000,0000", "10000.0000")
  cohortsToCreate <- rbind(cohortsToCreate, data.frame(cohortId = i,
                                                       cohortName = cohortName, 
                                                       sql = cohortSql,
                                                       stringsAsFactors = FALSE))
}

# Generate the cohort set against Eunomia. 
# cohortsGenerated contains a list of the cohortIds 
# successfully generated against the CDM
connectionDetails <- Eunomia::getEunomiaConnectionDetails()

# Create the cohort tables to hold the cohort generation results
cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = "my_cohort_table")
CohortGenerator::createCohortTables(connectionDetails = connectionDetails,
                                                        cohortDatabaseSchema = "main",
                                                        cohortTableNames = cohortTableNames)
# Generate the cohorts
cohortsGenerated <- CohortGenerator::generateCohortSet(connectionDetails = connectionDetails,
                                                       cdmDatabaseSchema = "main",
                                                       cohortDatabaseSchema = "main",
                                                       cohortTableNames = cohortTableNames,
                                                       cohortDefinitionSet = cohortsToCreate)
# sessionInfo()
