# root level keys
DMP = "dmp"
SKODA_DMP = "skoda_dmp"
SKODA_DMP_APPSTATE_TABLE = "skoda.skoda_dmp_kpi_appstate"
COUNTRY_AGG = "country_aggregate"
COUNTRY_AGG_TABLE = COUNTRY_AGG
SKODA_COUNTRY_AGG = "skoda_country_aggregate"
SKODA_COUNTRY_AGG_TABLE = "skoda.skoda_country_aggregate"

IDENT = "identity"
IDENT_TABLE = "identity_kit"
PROF = "profile"
PROF_TABLE = PROF
AUTO_IMP = "auto_import"
WE_EXP = "weexperience"
WE_EXP_TABLE = WE_EXP
WE_EXP_DEV = "{}_dev".format(WE_EXP)
WE_EXP_PRD = "{}_prd".format(WE_EXP)
WE_EXP_DEV_TABLE = WE_EXP_DEV
WE_EXP_PRD_TABLE = WE_EXP_PRD

VCF = "vcf"
VCF_TABLE = VCF
VCF_M = "measurements"
VCF_E = "enrollments"
VCF_API_USAGE = "vcf_api_usage"
DEALERS = "dealers_all"

# Carnet file names, used to map to tables in LOAD_PARAMS
D_CAR_GROUP = "DET.KGZN3O.CARNET.DCARGR"
D_CAR = "DET.KGZN3O.CARNET.DCARMN"
SLI = "DET.KGZN3O.RWRT.SLI"
KVPS = "DET.KGZN3O.RWRT.KPVS.PRTN"
HIFA = "DET.KGZN3O.CARNET.HIFA.DE"

# constants
TABLE = "table_name"
PROPS = "data_props"
CARNET_TABLE = "carnet_table"
# optional table property to signal that
# delete statement should be issued prior to loading
PREPROCESS_DELETE = "DELETE_BEFORE_LOADING"

LOAD_PARAMS = {
    DMP: {
        "ingestordata": {
            TABLE: "dmp_kpi_ingestordata",
            PROPS: "delimiter ',' IGNOREHEADER 1",
        },
        "appstate": {
            TABLE: "dmp_kpi_appstate",
            PROPS: "delimiter ',' IGNOREHEADER 1",
        },
    },
    SKODA_DMP: {
        "appstate": {
            TABLE: SKODA_DMP_APPSTATE_TABLE,
            PROPS: "delimiter ',' IGNOREHEADER 1",
        },
    },
    SKODA_COUNTRY_AGG: {
        TABLE: SKODA_COUNTRY_AGG_TABLE,
        PROPS: "delimiter ',' IGNOREHEADER 1",
    },
    AUTO_IMP: {
        PROPS: "delimiter ',' IGNOREHEADER 1",
    },
    VCF: {
        VCF_M: {
            TABLE: VCF_TABLE,
            PROPS: "delimiter ',' IGNOREHEADER 1",
        },
        VCF_E: {
            TABLE: VCF_TABLE,
            PROPS: "delimiter ',' IGNOREHEADER 1",
        },
        VCF_API_USAGE: {
            TABLE: VCF_API_USAGE,
            PROPS: "delimiter ',' IGNOREHEADER 1",
        },
        PROPS: "delimiter ',' IGNOREHEADER 1",
    },
    IDENT: {
        TABLE: IDENT_TABLE,
        PROPS: """CSV quote '"' delimiter ',' IGNOREHEADER 1""",
    },
    PROF: {
        TABLE: PROF_TABLE,
        PROPS: "delimiter ',' IGNOREHEADER 1",
    },
    COUNTRY_AGG: {
        TABLE: COUNTRY_AGG_TABLE,
        PROPS: "delimiter ',' IGNOREHEADER 1",
    },
    WE_EXP: {
        WE_EXP_DEV: {
            TABLE: WE_EXP_DEV_TABLE,
            PROPS: "delimiter ',' IGNOREHEADER 1",
        },
        WE_EXP_PRD: {
            TABLE: WE_EXP_PRD_TABLE,
            PROPS: "delimiter ',' IGNOREHEADER 1",
        },
    },
    D_CAR_GROUP: {
        CARNET_TABLE: True,
        TABLE: "carnet.CARNET_D_CAR_GROUP",
        PROPS: "csv gzip delimiter ',' IGNOREHEADER 1",
    },
    SLI: {
        CARNET_TABLE: True,
        TABLE: "public.SLI",
        PROPS: "csv gzip delimiter ',' IGNOREHEADER 1",
    },
    D_CAR: {
        CARNET_TABLE: True,
        TABLE: "carnet.CARNET_D_CAR",
        PROPS: "csv gzip delimiter ',' IGNOREHEADER 1",
    },
    KVPS: {
        CARNET_TABLE: True,
        TABLE: "public.KVPS_PRTN",
        PROPS: "gzip delimiter '|' ACCEPTINVCHARS IGNOREHEADER 1",
    },
    HIFA: {
        CARNET_TABLE: True,
        TABLE: "carnet.HIFA_F_FZG_AUFTRAEGE",
        PROPS: "gzip delimiter '|' ACCEPTINVCHARS IGNOREHEADER 1",
    },
    DEALERS: {
        PREPROCESS_DELETE: True,
        TABLE: "public.kvps_dealers",
        PROPS: """FORMAT AS PARQUET""",
    },
}
