"""seed notable aircraft types and military callsign prefixes

Revision ID: 009
Revises: 008
Create Date: 2026-06-13
"""
from alembic import op
import sqlalchemy as sa

revision = "009"
down_revision = "008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Notable aircraft types (ICAO designators)
    notable_types_table = sa.table(
        "notable_types",
        sa.column("type_code", sa.String(10)),
        sa.column("description", sa.String),
        sa.column("rarity_tier", sa.SmallInteger),
    )

    notable_types_data = [
        # Very large cargo/transport (rare, high rarity tier = lower score = LESS interesting)
        # These are genuinely rare aircraft, so rarity_tier is high (7-9)
        {"type_code": "A225", "description": "Antonov An-225 Mriya (world's largest aircraft by length)", "rarity_tier": 9},
        {"type_code": "A124", "description": "Antonov An-124 Ruslan (massive strategic airlifter)", "rarity_tier": 8},
        {"type_code": "A380", "description": "Airbus A380 (double-deck widebody, largest passenger)", "rarity_tier": 7},
        {"type_code": "B748", "description": "Boeing 747-8 (latest jumbo freighter variant)", "rarity_tier": 7},
        {"type_code": "BLCF", "description": "Boeing 747 Large Cargo Freighter (Dreamlifter)", "rarity_tier": 8},

        # Classic large jetliners
        {"type_code": "B742", "description": "Boeing 747-200 (classic jumbo, declining in service)", "rarity_tier": 6},
        {"type_code": "B743", "description": "Boeing 747-300 (stretched classic jumbo)", "rarity_tier": 6},
        {"type_code": "DC85", "description": "Douglas DC-8 (1960s narrow-body jet, rare in service)", "rarity_tier": 8},

        # Supersonic/historic jets
        {"type_code": "CONC", "description": "Concorde (supersonic, no longer in service but rare)", "rarity_tier": 9},

        # Business/large jets
        {"type_code": "GLF6", "description": "Gulfstream G650ER (ultra-long-range business jet)", "rarity_tier": 4},
        {"type_code": "GLEX", "description": "Gulfstream G650 (large-cabin business jet)", "rarity_tier": 4},
        {"type_code": "FA7X", "description": "Dassault Falcon 7X (heavy business jet)", "rarity_tier": 4},
        {"type_code": "CL60", "description": "Bombardier Challenger 600 (business twin-jet)", "rarity_tier": 3},

        # Military transport/strategic
        {"type_code": "C130", "description": "Lockheed C-130 Hercules (tactical airlifter)", "rarity_tier": 3},
        {"type_code": "C17", "description": "Boeing C-17 Globemaster III (strategic airlifter)", "rarity_tier": 4},
        {"type_code": "C5", "description": "Lockheed C-5 Galaxy (largest US military airlifter)", "rarity_tier": 5},
        {"type_code": "IL76", "description": "Ilyushin Il-76 (Soviet-era strategic transport)", "rarity_tier": 5},

        # Special government/VIP
        {"type_code": "VC25", "description": "Air Force One (Boeing 747 designation)", "rarity_tier": 9},
        {"type_code": "E4B", "description": "Boeing E-4B Nightwatch (ICBM command post)", "rarity_tier": 9},
        {"type_code": "E6B", "description": "Boeing E-6B Mercury (navy nuclear command post)", "rarity_tier": 8},
        {"type_code": "B737", "description": "Boeing C-40 (military VIP transport 737)", "rarity_tier": 3},
        {"type_code": "A320", "description": "Airbus ACJ320 (military VIP transport A320)", "rarity_tier": 4},

        # Military jets (fighters/interceptors)
        {"type_code": "F15", "description": "Boeing F-15 Eagle (air superiority fighter)", "rarity_tier": 2},
        {"type_code": "F16", "description": "General Dynamics F-16 Fighting Falcon (multirole fighter)", "rarity_tier": 2},
        {"type_code": "F18", "description": "Boeing F/A-18 Super Hornet (carrier fighter)", "rarity_tier": 2},
        {"type_code": "F22", "description": "Lockheed F-22 Raptor (5th-gen air superiority)", "rarity_tier": 8},
        {"type_code": "F35", "description": "Lockheed F-35 Lightning II (5th-gen multirole)", "rarity_tier": 7},
        {"type_code": "MIR2", "description": "MiG-31 (Soviet high-altitude interceptor)", "rarity_tier": 6},
        {"type_code": "RJ85", "description": "British Aerospace Jetstream 31 (regional twin-engine)", "rarity_tier": 3},

        # Historical/vintage warbirds (extremely rare in flight)
        {"type_code": "DC3", "description": "Douglas DC-3 (1935 transport, vintage flying example)", "rarity_tier": 9},
        {"type_code": "B17", "description": "Boeing B-17 Flying Fortress (WWII bomber, rare flying example)", "rarity_tier": 9},
        {"type_code": "B29", "description": "Boeing B-29 Superfortress (WWII strategic bomber, extremely rare)", "rarity_tier": 10},
        {"type_code": "LANC", "description": "Avro Lancaster (WWII heavy bomber, rare flying example)", "rarity_tier": 10},
        {"type_code": "SPIT", "description": "Supermarine Spitfire (WWII fighter, flying examples rare)", "rarity_tier": 8},
        {"type_code": "P51", "description": "North American P-51 Mustang (WWII escort fighter, rare airworthy)", "rarity_tier": 8},
        {"type_code": "JU52", "description": "Junkers Ju 52 (WWII transport, extremely rare airworthy)", "rarity_tier": 10},
        {"type_code": "ME262", "description": "Messerschmitt Me 262 (WWII jet fighter, extremely rare flying)", "rarity_tier": 10},

        # Amphibious/specialized
        {"type_code": "CL415", "description": "Bombardier CL-415 (amphibious firefighter)", "rarity_tier": 5},
        {"type_code": "DHC6", "description": "de Havilland Twin Otter (STOL bush plane)", "rarity_tier": 3},

        # Regional/smaller military
        {"type_code": "C21", "description": "Learjet C-21 (executive jet transport)", "rarity_tier": 4},
        {"type_code": "E2D", "description": "Grumman E-2D Hawkeye (airborne warning & control)", "rarity_tier": 6},
        {"type_code": "P8", "description": "Boeing P-8 Poseidon (maritime patrol/anti-sub)", "rarity_tier": 6},
        {"type_code": "RC135", "description": "Boeing RC-135 Rivet Joint (strategic reconnaissance)", "rarity_tier": 8},

        # Notably slow/unusual civilian
        {"type_code": "PC12", "description": "Pilatus PC-12 (single-engine pressurized)", "rarity_tier": 2},

        # Soviet/Russian rare
        {"type_code": "TU95", "description": "Tupolev Tu-95 Bear (Soviet strategic bomber)", "rarity_tier": 6},
        {"type_code": "AN32", "description": "Antonov An-32 (medium transport)", "rarity_tier": 4},
        {"type_code": "YAK40", "description": "Yakovlev Yak-40 (Soviet regional jet, rare)", "rarity_tier": 6},
    ]

    op.bulk_insert(notable_types_table, notable_types_data)

    # Military callsign prefixes
    mil_prefixes_table = sa.table(
        "mil_callsign_prefixes",
        sa.column("prefix", sa.String(10)),
        sa.column("description", sa.String),
    )

    mil_prefixes_data = [
        # US Air Force
        {"prefix": "RCH", "description": "US Air Mobility Command (Reach)"},
        {"prefix": "DUKE", "description": "US Air Force Transport"},
        {"prefix": "POLAR", "description": "US Air Force Polar airlift"},
        {"prefix": "ARMY", "description": "US Army Aviation"},
        {"prefix": "GIANT", "description": "US Military Airlift"},
        {"prefix": "MAGIC", "description": "US Air Force Transport"},

        # US Navy
        {"prefix": "CONVOY", "description": "US Navy Transport"},
        {"prefix": "SPLASH", "description": "US Navy (anti-ship)"},
        {"prefix": "SUNFISH", "description": "US Navy Maritime patrol"},

        # Canadian
        {"prefix": "CFC", "description": "Canadian Forces Command"},
        {"prefix": "MAPL", "description": "Canadian Forces Transport"},

        # UK RAF
        {"prefix": "RRR", "description": "Royal Air Force"},
        {"prefix": "ASCOT", "description": "RAF Transport"},

        # NATO generic
        {"prefix": "NATO", "description": "NATO Air Command"},
        {"prefix": "AVRO", "description": "NATO Military"},

        # Germany Luftwaffe
        {"prefix": "GAF", "description": "German Air Force (Luftwaffe)"},
        {"prefix": "MEDEVAC", "description": "German Military Evacuation"},

        # France ALAT/Air Force
        {"prefix": "FAF", "description": "French Air Force (Armée de l'Air)"},
        {"prefix": "EVASAN", "description": "French Military Evacuation"},

        # Italy
        {"prefix": "IAM", "description": "Italian Air Force (Aeronautica Militare)"},

        # Netherlands/Belgium/Denmark
        {"prefix": "NAF", "description": "Netherlands Air Force"},
        {"prefix": "BAF", "description": "Belgian Air Force"},
        {"prefix": "KRONOS", "description": "Danish Air Force"},

        # Spain
        {"prefix": "SPA", "description": "Spanish Air Force"},

        # Greece
        {"prefix": "ZEUS", "description": "Greek Air Force"},

        # Poland
        {"prefix": "PAF", "description": "Polish Air Force"},

        # Sweden/Norway
        {"prefix": "SAAB", "description": "Swedish Air Force"},
        {"prefix": "TROLL", "description": "Norwegian Air Force"},

        # Portugal
        {"prefix": "PORTAIR", "description": "Portuguese Air Force"},

        # Israel
        {"prefix": "IAF", "description": "Israeli Air Force"},

        # Australia
        {"prefix": "AUAF", "description": "Royal Australian Air Force"},
        {"prefix": "RESCUE", "description": "Australian Military Rescue"},

        # Japan
        {"prefix": "JAF", "description": "Japan Air Self-Defense Force"},

        # South Korea
        {"prefix": "ROKAF", "description": "Republic of Korea Air Force"},

        # India
        {"prefix": "IAF", "description": "Indian Air Force"},

        # Russian
        {"prefix": "MOSCOW", "description": "Russian Air Force"},
        {"prefix": "AEROFLOT-VIP", "description": "Russian Government transport"},

        # Chinese
        {"prefix": "PLAAF", "description": "People's Liberation Army Air Force"},

        # UAE/Middle East
        {"prefix": "UAE", "description": "UAE Air Force"},

        # Generic military suffixes often heard
        {"prefix": "MEDEVAC", "description": "Military Medical Evacuation"},
        {"prefix": "FRED", "description": "Military Transport (common US callsign)"},
        {"prefix": "TAXI", "description": "Military Ground Movement"},
        {"prefix": "OVERLORD", "description": "Military Transport/Command"},
        {"prefix": "RAMROD", "description": "Military Fighter"},
        {"prefix": "VIPER", "description": "Military Fighter (often F-16)"},
    ]

    op.bulk_insert(mil_prefixes_table, mil_prefixes_data)


def downgrade() -> None:
    op.execute("DELETE FROM mil_callsign_prefixes")
    op.execute("DELETE FROM notable_types")
