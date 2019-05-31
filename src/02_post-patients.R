library(tidyverse)
library(lubridate)
library(edwr)
library(openxlsx)

# run MBO query
#   * Patients - by Procedure Code
#       - Facility (Curr): HH HERMANN
#       - Admit Date: 3/1/2019 - 5/30/2019
#       - Procedure Code: starts with 0210, 0211, 0212, 0213 (CABG)
#           02RF0 - AV replacement
#           02QG0 - MV repair
#           02RG0 - MV replacement


dir_raw <- "data/raw/post"
tzone <- "US/Central"

patients <- read_data(dir_raw, "patients", FALSE) %>%
    as.patients()

mbo_id <- concat_encounters(patients$millennium.id)
mbo_id

# run MBO queries
#   * Procedures - ICD-9/10-PCS
#   * Visit Data

procs <- read_data(dir_raw, "procedures", FALSE) %>%
    as.procedures() %>%
    filter(str_detect(proc.code, "0210|0211|0212|0213|02RF0|02QG0|02RG0")) %>%
    arrange(millennium.id, proc.date) %>%
    distinct(millennium.id, .keep_all = TRUE)

visits <- read_data(dir_raw, "visits", FALSE) %>%
    as.visits()

pt_list <- visits %>%
    inner_join(procs, by = "millennium.id") %>%
    mutate(
        proc.day = difftime(
            proc.date,
            floor_date(admit.datetime, unit = "day"),
            units = "days"
        )
    ) %>%
    mutate_at("proc.day", as.numeric) %>%
    filter(proc.day > 0)

pt_id <- concat_encounters(pt_list$millennium.id)
pt_id

# run MBO query
#   * Identifiers - by Millennium Encounter Id

ids <- read_data(dir_raw, "identifiers", FALSE) %>%
    as.id()

include <- pt_list %>%
    inner_join(ids, by = "millennium.id") %>%
    select(
        fin,
        admit.datetime,
        discharge.datetime,
        proc.date,
        proc.day,
        proc.code,
        admit.source,
        admit.type,
        nurse.unit.admit,
        nurse.unit.dc = nurse.unit
    ) %>%
    distinct(fin, .keep_all = TRUE)

write.xlsx(include, "data/external/post_patients.xlsx")
