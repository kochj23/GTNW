"""South Vietnam: State of Vietnam (1949-55) and Republic of Vietnam (1955-75)."""
from nations.common import H, P, add_source

WS = add_source("ws_vnm", "worldstatesmen.org: Vietnam", "https://www.worldstatesmen.org/Vietnam.html")
BRIT = "britannica"
WP = "wikipedia"
D = (WS, BRIT)
M = (WP, "rulers")

NATION = {
    "id": "VNM_S",
    "name": "South Vietnam (State of Vietnam / Republic of Vietnam)",
    "tier": 2,
    "periods": [
        P("1949-06", "1955-10", "State of Vietnam (associated state of the French Union)",
          gov="constitutional_monarchy_executive", capital="Saigon",
          removal=["royal_dismissal", "foreign_occupation", "coup"],
          succession="Former emperor Bao Dai as Chief of State (Quoc truong) under the Elysee Accords (Mar 1949); prime ministers appointed and dismissed by Bao Dai.",
          notes="Limited sovereignty under France until 1954. After Geneva (Jul 1954) confined to south of the 17th parallel. Bao Dai deposed by Diem's rigged referendum of 23 Oct 1955."),
        P("1955-10", "1963-11", "First Republic of Vietnam (Ngo Dinh Diem)",
          gov="personalist_dictatorship", capital="Saigon",
          removal=["coup", "assassination"],
          succession="Presidential republic (1956 constitution) dominated by the Ngo family and the Can Lao party; no prime minister.",
          notes="Ended by the ARVN generals' coup of 1-2 Nov 1963 (Diem and Nhu killed) with US acquiescence."),
        P("1963-11", "1967-10", "Military juntas",
          gov="military_junta", capital="Saigon",
          removal=["coup"],
          succession="Military Revolutionary Council (Duong Van Minh); Nguyen Khanh coup Jan 1964; repeated coups and a civilian interlude (Phan Khac Suu / Tran Van Huong / Phan Huy Quat); National Leadership Committee (Thieu chairman, Ky PM) from Jun 1965.",
          notes="Game: extreme instability - frequent coup checks."),
        P("1967-10", "1975-04", "Second Republic of Vietnam (Nguyen Van Thieu)",
          gov="presidential_republic", capital="Saigon",
          removal=["general_election", "coup", "foreign_occupation"],
          succession="1967 constitution: directly elected president (Thieu 1967, unopposed 1971). PM appointed by the president.",
          notes="Fell to North Vietnam on 30 Apr 1975; Provisional Revolutionary Government nominally ruled the South until reunification (2 Jul 1976)."),
    ],
    "roles": {
        "head_of_state": [
            H("Bao Dai", "Chief of State", "1949-06-14", "1955-10-26", D, native="Quoc truong", note="Diem acted for him from 30 Apr 1955; deposed by referendum"),
            H("Ngo Dinh Diem", "President", "1955-10-26", "1963-11-02", D, native="Tong thong", note="Killed in the coup"),
            H("Duong Van Minh", "Chairman of the Military Revolutionary Council", "1963-11-02", "1964-01-30", D),
            H("Nguyen Khanh", "Chairman of the Military Revolutionary Council", "1964-01-30", "1964-02-08", D),
            H("Duong Van Minh", "Chief of State", "1964-02-08", "1964-08-16", D),
            H("Nguyen Khanh", "President", "1964-08-16", "1964-08-27", D),
            H("Duong Van Minh", "Chairman of the Provisional Leadership Committee / Chief of State", "1964-08-27", "1964-10-26", D, note="Triumvirate with Khanh and Tran Thien Khiem 27 Aug - 8 Sep 1964"),
            H("Phan Khac Suu", "Chief of State", "1964-10-26", "1965-06-14", D),
            H("Nguyen Van Thieu", "Chairman of the National Leadership Committee", "1965-06-14", "1967-10-31", D),
            H("Nguyen Van Thieu", "President", "1967-10-31", "1975-04-21", D, note="Resigned as Saigon was encircled"),
            H("Tran Van Huong", "President", "1975-04-21", "1975-04-28", D),
            H("Duong Van Minh", "President", "1975-04-28", "1975-04-30", D, note="Surrendered to the PAVN"),
        ],
        "head_of_government": [
            H("Bao Dai", "Prime Minister (also Chief of State)", "1949-06-13", "1950-01-21", D),
            H("Nguyen Phan Long", "Prime Minister", "1950-01-21", "1950-04-26", D),
            H("Tran Van Huu", "Prime Minister", "1950-04-27", "1952-06-06", D),
            H("Nguyen Van Tam", "Prime Minister", "1952-06-06", "1953-12-17", D),
            H("Buu Loc", "Prime Minister", "1954-01-12", "1954-06-16", D),
            H("Ngo Dinh Diem", "Prime Minister", "1954-06-26", "1955-10-26", D, note="Post abolished 1955-63"),
            H("Nguyen Ngoc Tho", "Prime Minister", "1963-11-04", "1964-01-30", D),
            H("Nguyen Khanh", "Prime Minister", "1964-02-08", "1964-11-04", D, note="Nguyen Xuan Oanh acting 29 Aug - 3 Sep 1964"),
            H("Tran Van Huong", "Prime Minister", "1964-11-04", "1965-01-28", D),
            H("Nguyen Xuan Oanh", "Acting Prime Minister", "1965-01-28", "1965-02-15", D, acting=True),
            H("Phan Huy Quat", "Prime Minister", "1965-02-16", "1965-06-08", D),
            H("Nguyen Cao Ky", "Chairman of the Central Executive Committee (Prime Minister)", "1965-06-19", "1967-10-31", D),
            H("Nguyen Van Loc", "Prime Minister", "1967-10-31", "1968-05-17", D),
            H("Tran Van Huong", "Prime Minister", "1968-05-28", "1969-09-01", D),
            H("Tran Thien Khiem", "Prime Minister", "1969-09-01", "1975-04-04", D),
            H("Nguyen Ba Can", "Prime Minister", "1975-04-04", "1975-04-24", D),
            H("Vu Van Mau", "Prime Minister", "1975-04-28", "1975-04-30", D),
        ],
        "foreign": [
            H("Vu Van Mau", "Secretary of State for Foreign Affairs", "1955", "1963-08", M, uncertain=True, note="Resigned and shaved his head in protest at the Xa Loi pagoda raids"),
            H("Tran Van Do", "Minister of Foreign Affairs", "1965-06", "1967-10", M, uncertain=True),
            H("Tran Van Lam", "Minister of Foreign Affairs", "1969-09", "1973-02", M, uncertain=True, note="Signed the Paris Peace Accords for the RVN"),
            H("Vuong Van Bac", "Minister of Foreign Affairs", "1973", "1975-04", M, uncertain=True),
        ],
        "defense": [
            H("Ngo Dinh Diem", "Secretary of State for Defence (held personally as President)", "1955-10", "1963-11", M, uncertain=True),
            H("Tran Van Don", "Minister of Defence", "1963-11", "1964-01", M, uncertain=True),
            H("Nguyen Van Thieu", "Minister of Defence", "1965-02", "1965-06", M, uncertain=True),
            H("Nguyen Huu Co", "Minister of Defence", "1965-06", "1967-01", M, uncertain=True),
            H("Nguyen Van Vy", "Minister of Defence", "1967", "1972", M, uncertain=True),
            H("Tran Thien Khiem", "Minister of Defence (also PM)", "1972", "1975-04", M, uncertain=True),
        ],
        "military_chief": [
            H("Cao Van Vien", "Chief of the Joint General Staff, ARVN", "1965-10", "1975-04-28", M, uncertain=True, note="Longest-serving JGS chief"),
        ],
    },
    "role_notes": {
        "foreign": "Coverage partial: 1963-65 and 1967-69 foreign ministers changed with each junta reshuffle and are not listed.",
        "defense": "Under Diem the president held defence himself. Coverage partial and uncertain.",
        "finance": "Not covered - finance ministers rotated rapidly; game should use generic 'Minister of Finance'.",
        "interior": "Not covered. Under Diem the real security apparatus was run by his brother Ngo Dinh Nhu (Political Adviser) - the game may treat Nhu (1955-63) as the de facto interior/security chief.",
        "intelligence": "Tran Kim Tuyen headed Diem's Office of Political and Social Studies (secret police) c.1956-62; later the Central Intelligence Organization (CIO, 1961-75). Heads not listed due to unverified dates.",
        "military_chief": "Before Cao Van Vien the JGS chiefs changed with each coup (e.g. Le Van Ty 1955-63, Tran Van Don 1963, Tran Thien Khiem 1964). Military figures dominated government 1963-75.",
    },
    "uncertain": [
        "All RVN cabinet-level ministers (foreign, defence) are from memory/Wikipedia without exact dates - flagged.",
        "JGS chiefs before Oct 1965 not listed.",
    ],
}
