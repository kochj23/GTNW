"""German Democratic Republic (East Germany), 7 Oct 1949 - 3 Oct 1990."""
from nations.common import H, P, add_source

WS_DEU = add_source("ws_germany", "worldstatesmen.org - Germany", "https://www.worldstatesmen.org/Germany.html")
RUL_DEU = add_source("rulers_germany", "rulers.org - Germany", "https://www.rulers.org/rulg1.html")
DHM = add_source("dhm_lemo", "Deutsches Historisches Museum - LeMO biographies & chronicle", "https://www.dhm.de/lemo/")
BSTU = add_source("stasi_unterlagen", "Bundesarchiv / Stasi-Unterlagen-Archiv - MfS leadership", "https://www.stasi-unterlagen-archiv.de/")
BRIT = "britannica"

S = (WS_DEU, RUL_DEU, DHM)

NATION = {
    "id": "DDR",
    "name": "East Germany (German Democratic Republic)",
    "tier": 1,
    "periods": [
        P("1949-10", "1989-11", "German Democratic Republic (SED rule)", "one_party_communist_state", "East Berlin",
          ["party_congress", "death_in_office", "revolution", "foreign_occupation"],
          succession="Real power with the SED First/General Secretary and Politburo; state posts (President/Council of State, Council of Ministers) filled by party decision and rubber-stamped by the Volkskammer. Leaders change by Central Committee/Politburo vote, often with Moscow's backing: Ulbricht forced out 1971, Honecker ousted by Politburo 17-18 Oct 1989.",
          notes="Soviet forces stationed throughout; 17 June 1953 uprising crushed by Soviet troops."),
        P("1989-11", "1990-10", "GDR transition (Peaceful Revolution to reunification)", "parliamentary_republic", "East Berlin",
          ["no_confidence", "general_election", "revolution"],
          succession="Berlin Wall opened 9 Nov 1989; SED's leading role struck from the constitution 1 Dec 1989; free Volkskammer election 18 Mar 1990; de Maizière government negotiated accession to the FRG (3 Oct 1990)."),
    ],
    "roles": {
        "paramount_leader": [
            H("Wilhelm Pieck & Otto Grotewohl", "Co-Chairmen of the SED", "1946-04", "1950-07", S, native="Vorsitzende der SED"),
            H("Walter Ulbricht", "General Secretary (1950-53), then First Secretary of the SED Central Committee", "1950-07", "1971-05", S + (BRIT,), native="Generalsekretär / Erster Sekretär des ZK der SED",
              note="Forced to resign by the Politburo with Brezhnev's consent."),
            H("Erich Honecker", "First Secretary, General Secretary from 1976, of the SED Central Committee", "1971-05", "1989-10", S + (BRIT,), native="Erster Sekretär / Generalsekretär des ZK der SED",
              note="Ousted by the Politburo 17 Oct 1989 (formal 18 Oct)."),
            H("Egon Krenz", "General Secretary of the SED Central Committee", "1989-10", "1989-12", S, native="Generalsekretär des ZK der SED", note="Politburo and CC resigned en bloc 3 Dec 1989."),
            H("Gregor Gysi", "Chairman of the SED-PDS", "1989-12", "1990-10", S, native="Vorsitzender der SED-PDS", note="Party no longer ruling."),
        ],
        "head_of_state": [
            H("Johannes Dieckmann", "Acting President (President of the Volkskammer)", "1949-10", "1949-10", S, acting=True),
            H("Wilhelm Pieck", "President of the Republic", "1949-10", "1960-09", S, native="Präsident der DDR", note="Died in office; presidency abolished."),
            H("Johannes Dieckmann", "Acting President", "1960-09", "1960-09", S, acting=True),
            H("Walter Ulbricht", "Chairman of the Council of State", "1960-09", "1973-08", S, native="Vorsitzender des Staatsrates", note="Died in office."),
            H("Friedrich Ebert Jr.", "Acting Chairman of the Council of State", "1973-08", "1973-10", S, acting=True),
            H("Willi Stoph", "Chairman of the Council of State", "1973-10", "1976-10", S, native="Vorsitzender des Staatsrates"),
            H("Erich Honecker", "Chairman of the Council of State", "1976-10", "1989-10", S, native="Vorsitzender des Staatsrates"),
            H("Egon Krenz", "Chairman of the Council of State", "1989-10", "1989-12", S, native="Vorsitzender des Staatsrates"),
            H("Manfred Gerlach", "Acting Chairman of the Council of State", "1989-12", "1990-04", S, acting=True, note="LDPD; the Staatsrat was abolished 5 Apr 1990."),
            H("Sabine Bergmann-Pohl", "President of the People's Chamber (acting head of state)", "1990-04", "1990-10", S, native="Präsidentin der Volkskammer", acting=True),
        ],
        "head_of_government": [
            H("Otto Grotewohl", "Minister-President; Chairman of the Council of Ministers from Dec 1958", "1949-10", "1964-09", S, native="Ministerpräsident / Vorsitzender des Ministerrates",
              note="Incapacitated from 1960; Stoph acting chairman from 1962/1964. Died 21 Sep 1964."),
            H("Willi Stoph", "Chairman of the Council of Ministers", "1964-09", "1973-10", S, native="Vorsitzender des Ministerrates"),
            H("Horst Sindermann", "Chairman of the Council of Ministers", "1973-10", "1976-10", S, native="Vorsitzender des Ministerrates"),
            H("Willi Stoph", "Chairman of the Council of Ministers", "1976-10", "1989-11", S, native="Vorsitzender des Ministerrates", note="Government resigned 7 Nov 1989."),
            H("Hans Modrow", "Chairman of the Council of Ministers", "1989-11", "1990-04", S, native="Vorsitzender des Ministerrates"),
            H("Lothar de Maizière", "Minister-President (Chairman of the Council of Ministers)", "1990-04", "1990-10", S, native="Ministerpräsident", note="Only freely elected GDR head of government (CDU)."),
        ],
        "foreign": [
            H("Georg Dertinger", "Minister of Foreign Affairs", "1949-10", "1953-01", S, native="Minister für Auswärtige Angelegenheiten", note="Arrested Jan 1953 in a show-trial purge."),
            H("Anton Ackermann", "Acting Minister of Foreign Affairs (State Secretary)", "1953-01", "1953-10", S, acting=True, uncertain=True),
            H("Lothar Bolz", "Minister of Foreign Affairs", "1953-10", "1965-06", S, native="Minister für Auswärtige Angelegenheiten"),
            H("Otto Winzer", "Minister of Foreign Affairs", "1965-06", "1975-01", S, native="Minister für Auswärtige Angelegenheiten"),
            H("Oskar Fischer", "Minister of Foreign Affairs", "1975-01", "1990-04", S, native="Minister für Auswärtige Angelegenheiten"),
            H("Markus Meckel", "Minister of Foreign Affairs", "1990-04", "1990-08", S, native="Minister für Auswärtige Angelegenheiten", note="SPD left the coalition Aug 1990."),
            H("Lothar de Maizière", "Minister-President, acting Foreign Minister", "1990-08", "1990-10", S, acting=True),
        ],
        "defense": [
            H("Willi Stoph", "Minister of National Defence", "1956-01", "1960-07", S, native="Minister für Nationale Verteidigung", note="NVA founded 1 Mar 1956; previously the Kasernierte Volkspolizei under the Interior Ministry."),
            H("Heinz Hoffmann", "Minister of National Defence", "1960-07", "1985-12", S, native="Minister für Nationale Verteidigung", note="Died in office."),
            H("Heinz Keßler", "Minister of National Defence", "1985-12", "1989-11", S, native="Minister für Nationale Verteidigung"),
            H("Theodor Hoffmann", "Minister of National Defence", "1989-11", "1990-04", S, native="Minister für Nationale Verteidigung"),
            H("Rainer Eppelmann", "Minister for Disarmament and Defence", "1990-04", "1990-10", S, native="Minister für Abrüstung und Verteidigung"),
        ],
        "finance": [
            H("Hans Loch", "Minister of Finance", "1949-10", "1955-11", S, native="Minister der Finanzen", uncertain=True),
            H("Willy Rumpf", "Minister of Finance", "1955-11", "1966-12", S, native="Minister der Finanzen", uncertain=True),
            H("Siegfried Böhm", "Minister of Finance", "1966-12", "1980-10", S, native="Minister der Finanzen", uncertain=True, note="Died in office."),
            H("Werner Schmieder", "Minister of Finance", "1980-10", "1981-06", S, native="Minister der Finanzen", uncertain=True),
            H("Ernst Höfner", "Minister of Finance", "1981-06", "1989-11", S, native="Minister der Finanzen", uncertain=True),
            H("Uta Nickel", "Minister of Finance and Prices", "1989-11", "1990-01", S, native="Ministerin der Finanzen und Preise", uncertain=True),
            H("Walter Siegert", "Acting Minister of Finance", "1990-01", "1990-04", S, acting=True, uncertain=True),
            H("Walter Romberg", "Minister of Finance", "1990-04", "1990-08", S, native="Minister der Finanzen"),
            H("Werner Skowron", "Acting Minister of Finance", "1990-08", "1990-10", S, acting=True, uncertain=True),
        ],
        "interior": [
            H("Karl Steinhoff", "Minister of the Interior", "1949-10", "1952-05", S, native="Minister des Innern"),
            H("Willi Stoph", "Minister of the Interior", "1952-05", "1955-07", S, native="Minister des Innern"),
            H("Karl Maron", "Minister of the Interior and Chief of the German People's Police", "1955-07", "1963-11", S, native="Minister des Innern"),
            H("Friedrich Dickel", "Minister of the Interior and Chief of the German People's Police", "1963-11", "1989-11", S, native="Minister des Innern"),
            H("Lothar Ahrendt", "Minister of Internal Affairs", "1989-11", "1990-04", S, native="Minister für Innere Angelegenheiten"),
            H("Peter-Michael Diestel", "Minister of the Interior", "1990-04", "1990-10", S, native="Minister des Innern"),
        ],
        "intelligence": [
            H("Wilhelm Zaisser", "Minister for State Security (Stasi)", "1950-02", "1953-07", (BSTU, DHM), native="Minister für Staatssicherheit", note="Purged after the June 1953 uprising."),
            H("Ernst Wollweber", "State Secretary, then Minister (Nov 1955) for State Security", "1953-07", "1957-11", (BSTU, DHM), native="Minister für Staatssicherheit"),
            H("Erich Mielke", "Minister for State Security", "1957-11", "1989-11", (BSTU, DHM, BRIT), native="Minister für Staatssicherheit",
              note="Foreign espionage (HV A) led by Markus Wolf 1952-86, then Werner Großmann."),
            H("Wolfgang Schwanitz", "Head of the Office for National Security (AfNS)", "1989-11", "1989-12", (BSTU, DHM), native="Leiter des Amtes für Nationale Sicherheit", note="AfNS dissolved Dec 1989-Jan 1990."),
        ],
        "military_chief": [
            H("Vincenz Müller", "Chief of the Main Staff of the NVA", "1956-03", "1958-02", (DHM,), native="Chef des Hauptstabes der NVA", uncertain=True),
            H("Sigfrid Riedel", "Chief of the Main Staff of the NVA", "1958-02", "1967", (DHM,), native="Chef des Hauptstabes der NVA", uncertain=True),
            H("Heinz Keßler", "Chief of the Main Staff of the NVA", "1967", "1978-12", (DHM,), native="Chef des Hauptstabes der NVA", uncertain=True),
            H("Fritz Streletz", "Chief of the Main Staff of the NVA", "1979-01", "1989-12", (DHM,), native="Chef des Hauptstabes der NVA", uncertain=True),
            H("Manfred Grätz", "Chief of the Main Staff of the NVA", "1989-12", "1990-10", (DHM,), native="Chef des Hauptstabes der NVA", uncertain=True),
        ],
    },
    "role_notes": {
        "paramount_leader": "The SED First/General Secretary is the real ruler; the game should make this the player's office, with Council of State / Council of Ministers posts as advisors. Removal by Politburo/Central Committee vote (Ulbricht 1971, Honecker 1989).",
        "defense": "No defence ministry 1949-56 (armed police under the Interior Ministry). Treat the Interior Minister as defence advisor 1949-56.",
        "intelligence": "MfS (Stasi) was briefly downgraded to a State Secretariat under the Interior Ministry (Jul 1953-Nov 1955).",
        "military_chief": "Soviet Group of Forces in Germany held real military power. NVA chiefs of the Main Staff: dates for 1958-1979 approximate.",
    },
    "uncertain": [
        "Finance ministers: names correct to best knowledge but several month-level dates unverified.",
        "NVA Chief of the Main Staff tenure dates 1956-1990 unverified at month level.",
        "Anton Ackermann's 1953 acting foreign ministry tenure dates approximate.",
    ],
}
