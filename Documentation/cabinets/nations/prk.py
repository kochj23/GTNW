"""North Korea (Democratic People's Republic of Korea) 1948-2026."""
from nations.common import H, P, add_source

WS_KP = add_source("ws_korea_north", "worldstatesmen.org: Korea (North) — leaders, party chiefs, SPA chairmen, premiers", "https://www.worldstatesmen.org/Korea_North.htm")
NKLW = add_source("nk_leadership_watch", "North Korea Leadership Watch (38 North) — personnel reporting", "https://www.nkleadershipwatch.org/")
WIKI_KP = add_source("wiki_kp_lists", "Wikipedia lists: Ministry of Foreign Affairs / Ministry of National Defence / Chief of the General Staff of the KPA / Ministry of State Security (DPRK) (cross-check only)",
                     "https://en.wikipedia.org/wiki/Chief_of_the_General_Staff_of_the_Korean_People%27s_Army")
UNIKOREA = add_source("unikorea", "ROK Ministry of Unification, 'Understanding North Korea' / North Korean power-structure charts", "https://www.unikorea.go.kr/eng_unikorea/")


def L(title, native, rows, sources):
    out = []
    for r in rows:
        kw = r[3] if len(r) > 3 else {}
        out.append(H(r[0], title, r[1], r[2], sources, native, **kw))
    return out


U = {"uncertain": True}

hos = L("Formal head of state", "", [
    ("Kim Tu-bong", "1948-09", "1957-09", {"note": "Chairman of the Standing Committee of the Supreme People's Assembly"}),
    ("Choe Yong-gon", "1957-09", "1972-12", {"note": "Chairman of the SPA Standing Committee"}),
    ("Kim Il Sung", "1972-12", "1994-07", {"note": "President of the DPRK (주석); declared 'Eternal President' in the 1998 constitution"}),
    ("Kim Yong-nam", "1998-09", "2019-04", {"note": "President of the SPA Presidium — nominal head of state for diplomatic purposes; presidency vacant 1994-07 to 1998-09"}),
    ("Kim Jong Un", "2019-04", "", {"note": "President of the State Affairs Commission; 2019 constitutional revision made the SAC chairman the representative of the state"}),
], (WS_KP, UNIKOREA))
ceremonial = L("Chairman of the SPA Presidium / Standing Committee (ceremonial)", "최고인민회의 상임위원회 위원장", [
    ("Choe Ryong-hae", "2019-04", "2026-03", {"note": "Also First Vice-President of the State Affairs Commission"}),
    ("Jo Yong-won", "2026-03", "", {"note": "Single-source (worldstatesmen) as of 2026-10", "uncertain": True}),
], (WS_KP,))
pl = L("Supreme Leader (party chief)", "", [
    ("Kim Il Sung", "1948-09", "1994-07", {"note": "Chairman of the Korean Workers' Party CC from 1949-06 (General Secretary from 1966-10)"}),
    ("Kim Jong Il", "1994-07", "2011-12", {"note": "Chairman of the National Defence Commission from 1993-04 ('highest post of the state' from 1998-09); WPK General Secretary from 1997-10"}),
    ("Kim Jong Un", "2011-12", "", {"note": "WPK First Secretary 2012-04, Chairman 2016-05, General Secretary 2021-01; NDC First Chairman 2012-04, SAC Chairman 2016-06"}),
], (WS_KP, "britannica"))
pm = L("Premier (Chairman of the Cabinet / Administration Council)", "내각 총리", [
    ("Kim Il Sung", "1948-09", "1972-12"),
    ("Kim Il", "1972-12", "1976-04"),
    ("Pak Song-chol", "1976-04", "1977-12"),
    ("Ri Jong-ok", "1977-12", "1984-01"),
    ("Kang Song-san", "1984-01", "1986-12"),
    ("Ri Kun-mo", "1986-12", "1988-12"),
    ("Yon Hyong-muk", "1988-12", "1992-12"),
    ("Kang Song-san", "1992-12", "1997-02"),
    ("Hong Song-nam", "1997-02", "2003-09", {"note": "Acting until 1998-09"}),
    ("Pak Pong-ju", "2003-09", "2007-04"),
    ("Kim Yong-il", "2007-04", "2010-06"),
    ("Choe Yong-rim", "2010-06", "2013-04"),
    ("Pak Pong-ju", "2013-04", "2019-04"),
    ("Kim Jae-ryong", "2019-04", "2020-08"),
    ("Kim Tok-hun", "2020-08", "2024-12"),
    ("Pak Thae-song", "2024-12", "", {"note": "Appointed at the WPK CC plenum announced 2024-12-29; sworn in at the SPA 2025-01"}),
], (WS_KP, NKLW))
fm = L("Minister of Foreign Affairs", "외무상", [
    ("Pak Hon-yong", "1948-09", "1953-03", {"note": "Purged and executed (1955)"}),
    ("Nam Il", "1953-03", "1959-10"),
    ("Pak Song-chol", "1959-10", "1970-07"),
    ("Ho Dam", "1970-07", "1983-12"),
    ("Kim Yong-nam", "1983-12", "1998-09"),
    ("Paek Nam-sun", "1998-09", "2007-01", {"note": "Died in office"}),
    ("Kang Sok-ju", "2007-01", "2007-05", {"acting": True}),
    ("Pak Ui-chun", "2007-05", "2014-04"),
    ("Ri Su-yong", "2014-04", "2016-05"),
    ("Ri Yong-ho", "2016-05", "2020-01"),
    ("Ri Son-gwon", "2020-01", "2022-06"),
    ("Choe Son-hui", "2022-06", "", {"note": "First female foreign minister"}),
], (WIKI_KP, "rulers"))
mod = L("Minister of National Defence (Minister of the People's Armed Forces until 2020)", "국방상 / 인민무력부장", [
    ("Choe Yong-gon", "1948-09", "1957-09"),
    ("Kim Kwang-hyop", "1957-09", "1962-10"),
    ("Kim Chang-bong", "1962-10", "1968-12"),
    ("Choe Hyon", "1968-12", "1976-05"),
    ("O Jin-u", "1976-05", "1995-02", {"note": "Died in office"}),
    ("Choe Kwang", "1995-10", "1997-02", {"note": "Died in office"}),
    ("Kim Il-chol", "1997-02", "2009-02", U),
    ("Kim Yong-chun", "2009-02", "2012-04"),
    ("Kim Jong-gak", "2012-04", "2012-11"),
    ("Kim Kyok-sik", "2012-11", "2013-05"),
    ("Jang Jong-nam", "2013-05", "2014-06"),
    ("Hyon Yong-chol", "2014-06", "2015-05", {"note": "Purged (reportedly executed) 2015"}),
    ("Pak Yong-sik", "2015-07", "2018-06", U),
    ("No Kwang-chol", "2018-06", "2019-12", U),
    ("Kim Jong-gwan", "2019-12", "2021-09", U),
    ("Ri Yong-gil", "2021-09", "2022-12", U),
    ("Kang Sun-nam", "2022-12", "2024-10"),
    ("No Kwang-chol", "2024-10", "2026-08", U),
    ("Kim Song-gi", "2026-08", "", {"note": "Single-source (Wikipedia) as of 2026-10", "uncertain": True}),
], (WIKI_KP, NKLW, UNIKOREA))
intel = L("Minister of State Security (State Security Department)", "국가보위상", [
    ("Kim Byong-ha", "1973", "1982", {"note": "First head of the separate State Political Security Department", "uncertain": True}),
    ("Kim Won-hong", "2012-04", "2017-02", {"note": "Dismissed 2017-01/02", "uncertain": True}),
    ("Jong Kyong-thaek", "2018", "2022", U),
    ("Ri Chang-dae", "2022", "2025", U),
    ("Pang Tu-sop", "2025-11", "", {"note": "Reported as minister 2025-11", "uncertain": True}),
], (WIKI_KP, NKLW))
cgs = L("Chief of the General Staff of the Korean People's Army", "조선인민군 총참모장", [
    ("Kang Kon", "1948-02", "1950-09", {"note": "Killed in action"}),
    ("Nam Il", "1950-09", "1953-08"),
    ("Kim Kwang-hyop", "1953-08", "1957-09"),
    ("Ri Kwon-mu", "1957-09", "1959-07"),
    ("Kim Chang-bong", "1959-07", "1962-10"),
    ("Choe Kwang", "1962-10", "1968-12", {"note": "Purged 1969, rehabilitated later"}),
    ("O Jin-u", "1968-12", "1979-09"),
    ("O Kuk-ryol", "1979-09", "1988-02"),
    ("Choe Kwang", "1988-02", "1995-10"),
    ("Kim Yong-chun", "1995-10", "2007-04"),
    ("Kim Kyok-sik", "2007-04", "2009-02"),
    ("Ri Yong-ho", "2009-02", "2012-07", {"note": "Purged"}),
    ("Hyon Yong-chol", "2012-07", "2013-05"),
    ("Kim Kyok-sik", "2013-05", "2013-08"),
    ("Ri Yong-gil", "2013-08", "2016-01"),
    ("Ri Myong-su", "2016-02", "2018-06"),
    ("Ri Yong-gil", "2018-06", "2019-09"),
    ("Pak Jong-chon", "2019-09", "2021-09"),
    ("Rim Kwang-il", "2021-09", "2022-06"),
    ("Ri Thae-sop", "2022-06", "2022-12", U),
    ("Pak Su-il", "2022-12", "2023-08", U),
    ("Ri Yong-gil", "2023-08", "", U),
], (WIKI_KP, NKLW))

NATION = {
    "id": "PRK",
    "name": "North Korea (Democratic People's Republic of Korea)",
    "tier": 2,
    "periods": [
        P("1945-08", "1948-09", "Soviet Civil Administration / Provisional People's Committee for North Korea", "colonial_or_occupied", "Pyongyang",
          ["foreign_occupation"], notes="Soviet occupation north of the 38th parallel; Kim Il Sung chairman of the Provisional People's Committee from 1946-02."),
        P("1948-09", "1994-07", "DPRK under Kim Il Sung", "one_party_communist_state", "Pyongyang",
          ["death_in_office", "party_congress", "coup"],
          succession="Kim Il Sung as party chairman/General Secretary and (from 1972) President; rival factions purged (1956 August Faction Incident). Kim Jong Il designated successor from 1974/1980.",
          notes="Korean War 1950-53. Juche ideology."),
        P("1994-07", "2011-12", "DPRK under Kim Jong Il ('military-first' Songun)", "one_party_communist_state", "Pyongyang",
          ["death_in_office", "coup"],
          succession="Hereditary succession within the Kim family, ratified by party and SPA organs.",
          notes="Power exercised via the National Defence Commission; famine 1994-98; nuclear tests from 2006."),
        P("2011-12", "", "DPRK under Kim Jong Un", "one_party_communist_state", "Pyongyang",
          ["death_in_office", "coup", "revolution"],
          succession="Hereditary (Kim family 'Paektu bloodline'); offices conferred by WPK congresses/plenums and SPA sessions.",
          notes="Game: no elections or no-confidence; the player (Kim) can only be removed by death, coup or revolution. Ministers and generals are removed at will (purges)."),
    ],
    "roles": {
        "head_of_state": hos + ceremonial,
        "paramount_leader": pl,
        "head_of_government": pm,
        "foreign": fm,
        "defense": mod,
        "intelligence": intel,
        "military_chief": cgs,
    },
    "role_notes": {
        "head_of_state": "Formal head of state changed several times: SPA Standing Committee chairman (1948-72), President (1972-94), SPA Presidium chairman as nominal head of state (1998-2019), SAC President since 2019. The SPA chairman is listed separately after 2019 as ceremonial.",
        "paramount_leader": "The game should make the Supreme Leader the player's office.",
        "head_of_government": "The Premier manages the economy only; no foreign or security authority.",
        "finance": "Ministers of Finance are obscure and not listed; the game should use the Premier/economic vice-premiers as the finance advisor.",
        "interior": "Ministry of Social Security (formerly People's Security) runs police; ministers not listed (gap; frequently changed and poorly documented).",
        "intelligence": "Ministry of State Security (secret police) and the Reconnaissance General Bureau (military intelligence, from 2009). Heads are often unannounced; all entries uncertain. 1982-2012 the post was often nominally held or vacant with first vice-directors in charge.",
        "defense": "The Minister of National Defence is subordinate to the General Political Bureau and the Central Military Commission of the WPK.",
    },
    "uncertain": [
        "Defence ministers after 2015 and all State Security ministers: dates from secondary reporting; DPRK rarely announces appointments.",
        "Jo Yong-won as SPA Standing Committee chairman (2026-03) and Kim Song-gi as defence minister (2026-08): single-source.",
        "KPA chief of general staff 2022-23 sequence and Ri Yong-gil's third tenure start (2022-12 vs 2023-08).",
    ],
}
