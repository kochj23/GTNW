"""Shared helpers and source registry for GTNW cabinet data.

Every nation module in this package defines a module-level dict NATION with this shape:

NATION = {
    "id": "GBR",                       # stable game id (ISO-3 style; historical states use the modern successor id + period)
    "name": "United Kingdom",
    "tier": 1,
    "periods": [                       # contiguous, chronological; covers 1789-2030 where the state existed
        P("1801-01", "", "United Kingdom of Great Britain and Ireland",
          gov="constitutional_monarchy_parliamentary", capital="London",
          removal=["no_confidence", "loss_of_party_leadership", "general_election"],
          succession="...", notes="..."),
    ],
    "roles": {                         # role keys are fixed (see ROLE_KEYS)
        "head_of_state": [H(...), ...],
        "head_of_government": [...],
        "foreign": [...], "defense": [...], "finance": [...],
        "interior": [...], "intelligence": [...], "military_chief": [...],
    },
    "role_notes": {"intelligence": "No public chief before 1909 ...", ...},  # absence / game-handling notes
    "uncertain": ["free-text list of anything flagged"],
}

Dates are strings: "YYYY-MM" (preferred), "YYYY-MM-DD", or "YYYY" where only the year is known.
to="" means still in office as of the dataset cut-off (2026-10).
"""

ROLE_KEYS = [
    "head_of_state",
    "head_of_government",
    "foreign",
    "defense",
    "finance",
    "interior",
    "intelligence",
    "military_chief",
]

# Removal mechanism vocabulary used by the game engine.
REMOVAL_KEYS = {
    "no_confidence": "Lower house / legislature passes a vote of no confidence (or government loses confidence/supply)",
    "constructive_no_confidence": "Legislature elects a successor and thereby removes the head of government (e.g. FRG Art. 67, Spain 1978, Israel since 2001)",
    "general_election": "Loses a scheduled or snap general election",
    "loss_of_party_leadership": "Ruling party replaces its leader, who then resigns as head of government",
    "royal_dismissal": "Monarch/emperor dismisses the minister or head of government",
    "presidential_dismissal": "President dismisses the prime minister/cabinet",
    "impeachment": "Formal impeachment / removal trial by legislature or court",
    "term_limit": "Constitutional term limit forces departure",
    "party_congress": "Removed by party Central Committee / Politburo / congress (one-party states)",
    "coup": "Military or palace coup",
    "revolution": "Popular revolution / regime collapse",
    "assassination": "Assassination (event, not a procedure; listed where historically common)",
    "abdication": "Monarch abdicates (forced or voluntary)",
    "foreign_occupation": "Removed by foreign conquest / occupation",
    "death_in_office": "Lifetime office; ends only with death (plus other listed mechanisms)",
    "religious_council": "Removal by a clerical body (e.g. Iran's Assembly of Experts)",
    "junta_decision": "Removed by the ruling junta / military high command (e.g. Argentina 1976-83, Brazil 1964-85)",
    "family_council": "Royal family / dynastic council deposes the ruler (e.g. Saudi Arabia 1964)",
}

# Source registry. Holder entries refer to keys; build.py expands them to {key, title, url}.
SOURCES = {
    "britannica": ("Encyclopaedia Britannica", "https://www.britannica.com/"),
    "rulers": ("Ben Cahoon, rulers.org (heads of state/government and foreign ministers by country)", "https://www.rulers.org/"),
    "worldstatesmen": ("Ben Cahoon, worldstatesmen.org (country pages)", "https://www.worldstatesmen.org/"),
    "wikipedia": ("Wikipedia (cross-check only)", "https://en.wikipedia.org/"),
}


def src(*keys):
    return list(keys)


def H(name, title, frm, to, sources=("worldstatesmen", "rulers"), native="", note="", uncertain=False, acting=False):
    """One office holder."""
    d = {
        "name": name,
        "title": title,
        "native_title": native,
        "from": frm,
        "to": to,
        "sources": list(sources),
    }
    if note:
        d["note"] = note
    if uncertain:
        d["uncertain"] = True
    if acting:
        d["acting"] = True
    return d


def P(frm, to, name, gov, capital, removal, succession="", notes="", cabinet=True):
    """One period of a nation's political history."""
    return {
        "from": frm,
        "to": to,
        "name": name,
        "government_type": gov,
        "capital": capital,
        "removal_mechanisms": list(removal),
        "succession": succession,
        "notes": notes,
        "has_cabinet": cabinet,
    }


def add_source(key, title, url):
    """Nation modules may register extra sources (e.g. a parliament's official list)."""
    SOURCES[key] = (title, url)
    return key


# Government-type vocabulary (period["government_type"] must be one of these).
GOV_TYPES = [
    "absolute_monarchy",
    "constitutional_monarchy_parliamentary",   # monarch reigns, PM/cabinet responsible to parliament (UK, Japan post-1947, Spain 1978+)
    "constitutional_monarchy_executive",       # monarch retains real executive power; ministers answer to the crown (Prussia, German Empire, Meiji Japan)
    "parliamentary_republic",
    "presidential_republic",
    "semi_presidential_republic",
    "one_party_communist_state",
    "one_party_state",                          # non-communist single party (Nazi Germany, Fascist Italy, PRI Mexico de facto)
    "military_junta",
    "personalist_dictatorship",
    "theocratic_republic",                      # Islamic Republic of Iran
    "revolutionary_government",                 # transitional/provisional (French Convention, Russian Provisional Govt)
    "colonial_or_occupied",                     # under foreign administration
    "dominion",                                 # self-governing dominion of the British Crown
    "empire_napoleonic",                        # Napoleonic / Bonapartist authoritarian empire
]
