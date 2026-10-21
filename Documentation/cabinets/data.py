"""GTNW leaders & cabinets dataset (1789-2030).

The per-nation data lives in nations/<id>.py (one module per nation, each defines NATION).
This module aggregates them and holds the generic role titles used for every nation
that has no named data (tier 3).
"""
import importlib
import pkgutil
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from nations.common import SOURCES, ROLE_KEYS, REMOVAL_KEYS, GOV_TYPES  # noqa: E402

DATASET_CUTOFF = "2026-10"


def load_nations():
    import nations
    out = []
    for m in pkgutil.iter_modules(nations.__path__):
        if m.name == "common" or m.name.startswith("_"):
            continue
        mod = importlib.import_module(f"nations.{m.name}")
        n = getattr(mod, "NATION", None)
        if n is None:
            continue
        out.append(n)
    out.sort(key=lambda n: (n["tier"], n["name"]))
    return out


# ---------------------------------------------------------------------------
# Tier 3: generic role titles by government type (no names).
# Keys mirror ROLE_KEYS. A value of None means "role does not exist in this form";
# the matching *_note explains how the game should handle it.
# ---------------------------------------------------------------------------
GENERIC_ROLES = {
    "absolute_monarchy": {
        "head_of_state": "King / Emperor / Sultan / Shah / Emir",
        "head_of_government": "Chief Minister / Grand Vizier / Chancellor (appointed by and serving at the pleasure of the monarch)",
        "foreign": "Minister / Secretary of State for Foreign Affairs",
        "defense": "Minister of War",
        "finance": "Minister of Finance / Treasurer",
        "interior": "Minister of the Interior / Royal Household",
        "intelligence": None,
        "military_chief": "Commander-in-Chief (often the monarch or a royal prince)",
        "notes": "Monarch may act as own foreign minister and commander. Ministers removed by royal dismissal; ruler removed only by death, abdication, palace coup, revolution or foreign conquest. Before c.1900 there is usually no standing intelligence chief: model as a court/police function.",
        "removal": ["royal_dismissal", "death_in_office", "abdication", "coup", "revolution", "assassination", "foreign_occupation"],
    },
    "constitutional_monarchy_parliamentary": {
        "head_of_state": "King / Queen / Emperor (ceremonial)",
        "head_of_government": "Prime Minister",
        "foreign": "Minister of Foreign Affairs",
        "defense": "Minister of Defence (Minister of War / of the Navy before c.1945)",
        "finance": "Minister of Finance",
        "interior": "Minister of the Interior / Home Affairs",
        "intelligence": "Director of the Intelligence/Security Service",
        "military_chief": "Chief of the Defence Staff / Chief of the General Staff",
        "notes": "Monarch reigns but does not rule; PM depends on parliamentary majority.",
        "removal": ["no_confidence", "general_election", "loss_of_party_leadership"],
    },
    "constitutional_monarchy_executive": {
        "head_of_state": "King / Emperor (holds executive power)",
        "head_of_government": "Minister-President / Chancellor / Prime Minister (answerable to the crown)",
        "foreign": "Minister of Foreign Affairs",
        "defense": "Minister of War",
        "finance": "Minister of Finance",
        "interior": "Minister of the Interior",
        "intelligence": None,
        "military_chief": "Chief of the General Staff",
        "notes": "Parliament controls budgets but cannot directly dismiss ministers; removal is by the monarch.",
        "removal": ["royal_dismissal", "abdication", "revolution", "coup"],
    },
    "parliamentary_republic": {
        "head_of_state": "President (largely ceremonial, elected by parliament or people)",
        "head_of_government": "Prime Minister / Chancellor / Premier",
        "foreign": "Minister of Foreign Affairs",
        "defense": "Minister of Defence",
        "finance": "Minister of Finance",
        "interior": "Minister of the Interior",
        "intelligence": "Director of the National Intelligence Service",
        "military_chief": "Chief of the General Staff / Chief of Defence",
        "notes": "",
        "removal": ["no_confidence", "general_election", "loss_of_party_leadership"],
    },
    "presidential_republic": {
        "head_of_state": "President",
        "head_of_government": "President (head of state and government)",
        "foreign": "Secretary / Minister of Foreign Affairs (Foreign Relations)",
        "defense": "Minister / Secretary of Defence (National Defence)",
        "finance": "Minister / Secretary of Finance (Treasury)",
        "interior": "Minister / Secretary of the Interior (Government)",
        "intelligence": "Director of National Intelligence",
        "military_chief": "Chief of the Armed Forces Joint Staff",
        "notes": "Fixed terms; legislature cannot dismiss president except by impeachment.",
        "removal": ["impeachment", "term_limit", "general_election", "coup"],
    },
    "semi_presidential_republic": {
        "head_of_state": "President",
        "head_of_government": "Prime Minister (appointed by the president, responsible to parliament)",
        "foreign": "Minister of Foreign Affairs",
        "defense": "Minister of Defence",
        "finance": "Minister of Finance / Economy",
        "interior": "Minister of the Interior",
        "intelligence": "Director of the State Security / Intelligence Service",
        "military_chief": "Chief of the General Staff / Chief of Defence Staff",
        "notes": "President removed by election/impeachment; PM by no-confidence or presidential dismissal.",
        "removal": ["general_election", "impeachment", "no_confidence", "presidential_dismissal"],
    },
    "one_party_communist_state": {
        "head_of_state": "Chairman of the Presidium / President of the State",
        "head_of_government": "Premier / Chairman of the Council of Ministers",
        "paramount_leader": "General Secretary (First Secretary) of the Central Committee",
        "foreign": "Minister of Foreign Affairs",
        "defense": "Minister of National Defence",
        "finance": "Minister of Finance",
        "interior": "Minister of the Interior / Public Security",
        "intelligence": "Chairman of State Security (secret police)",
        "military_chief": "Chief of the General Staff",
        "notes": "Real power sits with the party General Secretary and Politburo; the game should treat the GS as the player's office and state posts as advisors. No-confidence does not exist; removal is by Politburo/Central Committee vote, death, or revolution.",
        "removal": ["party_congress", "death_in_office", "coup", "revolution"],
    },
    "one_party_state": {
        "head_of_state": "President / Leader",
        "head_of_government": "Prime Minister / Leader of the ruling party",
        "foreign": "Minister of Foreign Affairs",
        "defense": "Minister of Defence / War",
        "finance": "Minister of Finance",
        "interior": "Minister of the Interior",
        "intelligence": "Chief of the Secret Police / State Security",
        "military_chief": "Chief of the General Staff",
        "notes": "Legislature is a rubber stamp; removal by coup, party intrigue, revolution or defeat in war.",
        "removal": ["coup", "revolution", "party_congress", "foreign_occupation", "death_in_office"],
    },
    "military_junta": {
        "head_of_state": "Chairman of the Junta / President of the Revolutionary Command Council",
        "head_of_government": "Chairman of the Junta (or appointed Prime Minister)",
        "foreign": "Minister of Foreign Affairs (often a civilian technocrat)",
        "defense": "Minister of Defence (a junta member)",
        "finance": "Minister of Finance (often a civilian technocrat)",
        "interior": "Minister of the Interior (usually a general)",
        "intelligence": "Director of Military Intelligence / State Security",
        "military_chief": "Commanders of the Army, Navy and Air Force (collectively the junta)",
        "notes": "No elections or no-confidence; leader removed by counter-coup within the junta, popular revolution, or negotiated return to civilian rule.",
        "removal": ["junta_decision", "coup", "revolution"],
    },
    "personalist_dictatorship": {
        "head_of_state": "President / Leader (for life in practice)",
        "head_of_government": "President / Prime Minister (figurehead)",
        "foreign": "Minister of Foreign Affairs",
        "defense": "Minister of Defence",
        "finance": "Minister of Finance",
        "interior": "Minister of the Interior",
        "intelligence": "Head of the Presidential Guard / Secret Police",
        "military_chief": "Chief of the General Staff",
        "notes": "Ministers are courtiers removed at will. Ruler removed by death, coup, assassination or revolution.",
        "removal": ["coup", "revolution", "assassination", "death_in_office"],
    },
    "theocratic_republic": {
        "head_of_state": "Supreme Leader",
        "head_of_government": "President (elected; government head under the Supreme Leader)",
        "foreign": "Minister of Foreign Affairs",
        "defense": "Minister of Defence",
        "finance": "Minister of Economy and Finance",
        "interior": "Minister of the Interior",
        "intelligence": "Minister of Intelligence",
        "military_chief": "Chief of the General Staff of the Armed Forces",
        "notes": "Supreme Leader removable only by the clerical Assembly of Experts (never used); president by election, parliamentary impeachment or Supreme Leader dismissal.",
        "removal": ["religious_council", "general_election", "impeachment", "revolution"],
    },
    "revolutionary_government": {
        "head_of_state": "President of the Provisional Government / Chairman of the Revolutionary Council",
        "head_of_government": "Chairman of the Provisional Government",
        "foreign": "Commissioner / Minister of Foreign Affairs",
        "defense": "Commissioner / Minister of War",
        "finance": "Commissioner / Minister of Finance",
        "interior": "Commissioner / Minister of the Interior",
        "intelligence": "Head of the Revolutionary Security Committee",
        "military_chief": "Commander-in-Chief of the Revolutionary Army",
        "notes": "Short-lived and unstable; removal by factional purge, coup or counter-revolution.",
        "removal": ["coup", "revolution", "party_congress"],
    },
    "colonial_or_occupied": {
        "head_of_state": "Foreign sovereign (represented by a Governor-General / High Commissioner / Military Governor)",
        "head_of_government": "Governor-General / Military Governor (or a collaborating Prime Minister)",
        "foreign": None,
        "defense": None,
        "finance": "Colonial Treasurer",
        "interior": "Colonial Secretary / Chief Secretary",
        "intelligence": None,
        "military_chief": "Garrison Commander (foreign)",
        "notes": "Not playable as a sovereign actor; foreign and defence policy are controlled by the metropole/occupier. Ends by independence, revolution or the occupier's withdrawal.",
        "removal": ["revolution", "foreign_occupation"],
    },
    "dominion": {
        "head_of_state": "British Monarch (represented by a Governor-General)",
        "head_of_government": "Prime Minister",
        "foreign": "Secretary of State for External Affairs (handled by London before the 1920s-1931)",
        "defense": "Minister of Defence / Militia and Defence",
        "finance": "Minister of Finance / Treasurer",
        "interior": "Minister of the Interior / Home Affairs",
        "intelligence": None,
        "military_chief": "Chief of the General Staff",
        "notes": "Parliamentary (Westminster) system; foreign policy autonomy grew after the 1926 Balfour Declaration and 1931 Statute of Westminster.",
        "removal": ["no_confidence", "general_election", "loss_of_party_leadership"],
    },
    "empire_napoleonic": {
        "head_of_state": "Emperor",
        "head_of_government": "Emperor (no prime minister; ministers report individually)",
        "foreign": "Minister of Foreign Affairs",
        "defense": "Minister of War",
        "finance": "Minister of Finance",
        "interior": "Minister of the Interior / Minister of Police",
        "intelligence": "Minister of General Police",
        "military_chief": "Major-General (Chief of Staff) of the Grande Armée",
        "notes": "Authoritarian empire with plebiscitary legitimacy; ends by military defeat, abdication or revolution.",
        "removal": ["abdication", "foreign_occupation", "revolution", "coup"],
    },
}


NATIONS = load_nations()
