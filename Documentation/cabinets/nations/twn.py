"""Republic of China on Taiwan, 1949-2026 (pre-1949 ROC: see chn.py)."""
from nations.common import H, P, add_source

PRES = add_source("roc_president", "Office of the President, Republic of China (Taiwan): Former Presidents", "https://english.president.gov.tw/")
EY = add_source("roc_ey", "Executive Yuan, Republic of China (Taiwan): Past Premiers and Cabinet Members", "https://english.ey.gov.tw/")
MOFA_TW = add_source("mofa_tw", "Ministry of Foreign Affairs, ROC (Taiwan): Past Ministers", "https://en.mofa.gov.tw/")
MND_TW = add_source("mnd_tw", "Ministry of National Defense, ROC (Taiwan): Past Ministers", "https://www.mnd.gov.tw/english/")

WS = ("worldstatesmen", "rulers")


def L(title, native, rows, sources=WS):
    out = []
    for r in rows:
        kw = r[3] if len(r) > 3 else {}
        out.append(H(r[0], title, r[1], r[2], sources, native, **kw))
    return out


U = {"uncertain": True}

pres = L("President of the Republic of China", "中華民國總統", [
    ("Li Zongren", "1949-12", "1950-03", {"acting": True, "note": "Acting President in absentia (in the U.S.)"}),
    ("Chiang Kai-shek", "1950-03", "1975-04", {"note": "Resumed presidency in Taipei 1950-03-01; died in office"}),
    ("Yen Chia-kan (C. K. Yen)", "1975-04", "1978-05"),
    ("Chiang Ching-kuo", "1978-05", "1988-01", {"note": "Lifted martial law 1987-07; died in office"}),
    ("Lee Teng-hui", "1988-01", "2000-05", {"note": "First directly elected president (1996)"}),
    ("Chen Shui-bian", "2000-05", "2008-05", {"note": "First DPP president"}),
    ("Ma Ying-jeou", "2008-05", "2016-05"),
    ("Tsai Ing-wen", "2016-05", "2024-05"),
    ("Lai Ching-te (William Lai)", "2024-05", ""),
], (PRES, "worldstatesmen", "rulers"))
kmt = L("Paramount leader (KMT Director-General / Chairman)", "", [
    ("Chiang Kai-shek", "1949-12", "1975-04", {"note": "KMT Director-General (總裁)"}),
    ("Chiang Ching-kuo", "1975-04", "1988-01", {"note": "KMT Chairman; Premier 1972-78, then President — real power from 1975 even before the presidency"}),
], ("britannica",))
prem = L("President of the Executive Yuan (Premier)", "行政院院長", [
    ("Yan Xishan", "1949-06", "1950-03"),
    ("Chen Cheng", "1950-03", "1954-06"),
    ("O. K. Yui (Yu Hung-chun)", "1954-06", "1958-07"),
    ("Chen Cheng", "1958-07", "1963-12"),
    ("Yen Chia-kan (C. K. Yen)", "1963-12", "1972-06"),
    ("Chiang Ching-kuo", "1972-06", "1978-05"),
    ("Sun Yun-suan", "1978-05", "1984-05"),
    ("Yu Kuo-hwa", "1984-05", "1989-06"),
    ("Lee Huan", "1989-06", "1990-06"),
    ("Hau Pei-tsun", "1990-06", "1993-02"),
    ("Lien Chan", "1993-02", "1997-09"),
    ("Vincent Siew", "1997-09", "2000-05"),
    ("Tang Fei", "2000-05", "2000-10"),
    ("Chang Chun-hsiung", "2000-10", "2002-02"),
    ("Yu Shyi-kun", "2002-02", "2005-02"),
    ("Frank Hsieh", "2005-02", "2006-01"),
    ("Su Tseng-chang", "2006-01", "2007-05"),
    ("Chang Chun-hsiung", "2007-05", "2008-05"),
    ("Liu Chao-shiuan", "2008-05", "2009-09"),
    ("Wu Den-yih", "2009-09", "2012-02"),
    ("Sean Chen", "2012-02", "2013-02"),
    ("Jiang Yi-huah", "2013-02", "2014-12"),
    ("Mao Chi-kuo", "2014-12", "2016-02"),
    ("Chang San-cheng", "2016-02", "2016-05"),
    ("Lin Chuan", "2016-05", "2017-09"),
    ("Lai Ching-te (William Lai)", "2017-09", "2019-01"),
    ("Su Tseng-chang", "2019-01", "2023-01"),
    ("Chen Chien-jen", "2023-01", "2024-05"),
    ("Cho Jung-tai", "2024-05", ""),
], (EY, "worldstatesmen", "rulers"))
fm = L("Minister of Foreign Affairs", "外交部長", [
    ("George Yeh (Yeh Kung-chao)", "1949-10", "1958-07", {"note": "Acting 1949-10, confirmed 1950"}),
    ("Huang Shao-ku", "1958-07", "1960-05"),
    ("Shen Chang-huan", "1960-05", "1966-01"),
    ("Wei Tao-ming", "1966-01", "1971-03"),
    ("Chow Shu-kai", "1971-03", "1972-05", {"note": "ROC lost the UN seat 1971-10 (Resolution 2758)"}),
    ("Shen Chang-huan", "1972-06", "1978-12", {"note": "Resigned when the U.S. switched recognition to the PRC"}),
    ("Chu Fu-sung", "1979-01", "1987-04"),
    ("Ding Mou-shih", "1987-04", "1988-07"),
    ("Lien Chan", "1988-07", "1990-06"),
    ("Fredrick Chien", "1990-06", "1996-06"),
    ("John Chang", "1996-06", "1997-10"),
    ("Jason Hu", "1997-10", "1999-02"),
    ("Chen Chien-jen", "1999-02", "2000-05"),
    ("Tien Hung-mao", "2000-05", "2002-02"),
    ("Eugene Chien", "2002-02", "2004-05"),
    ("Mark Chen", "2004-05", "2006-01"),
    ("James Huang", "2006-01", "2008-05"),
    ("Francisco Ou", "2008-05", "2009-09"),
    ("Timothy Yang", "2009-09", "2012-09"),
    ("David Lin", "2012-09", "2016-05"),
    ("David Lee", "2016-05", "2018-02"),
    ("Joseph Wu", "2018-02", "2024-05"),
    ("Lin Chia-lung", "2024-05", ""),
], (MOFA_TW, "rulers", "worldstatesmen"))
mnd = L("Minister of National Defense", "國防部長", [
    ("Xu Yongchang", "1948-12", "1949-04", U),
    ("He Yingqin", "1949-05", "1949-06", U),
    ("Yan Xishan", "1949-06", "1950-01", {"note": "Concurrently Premier"}),
    ("Gu Zhutong", "1950-02", "1950-03", U),
    ("Yu Ta-wei", "1950-04", "1951-02", {"note": "Nominal while abroad", "uncertain": True}),
    ("Kuo Chi-chiao", "1951-03", "1954-05", U),
    ("Yu Ta-wei", "1954-06", "1965-01"),
    ("Chiang Ching-kuo", "1965-01", "1969-06"),
    ("Huang Chieh", "1969-07", "1972-05"),
    ("Chen Ta-ching", "1972-06", "1973-06"),
    ("Kao Kuei-yuan", "1973-07", "1981-11"),
    ("Soong Chang-chih", "1981-12", "1986-06"),
    ("Wang Daoyuan", "1986-07", "1987-04"),
    ("Cheng Wei-yuan", "1987-04", "1989-12"),
    ("Hau Pei-tsun", "1989-12", "1990-05", {"note": "Some lists extend his tenure to 1991-05", "uncertain": True}),
    ("Chen Li-an", "1990-06", "1993-02", U),
    ("Sun Chen", "1993-02", "1994-12"),
    ("Chiang Chung-ling", "1994-12", "1999-01"),
    ("Tang Fei", "1999-02", "2000-05"),
    ("Wu Shih-wen", "2000-05", "2002-02"),
    ("Tang Yao-ming", "2002-02", "2004-05"),
    ("Lee Jye", "2004-05", "2007-05"),
    ("Lee Tien-yu", "2007-05", "2008-02"),
    ("Michael Tsai", "2008-02", "2008-05"),
    ("Chen Chao-min", "2008-05", "2009-09"),
    ("Kao Hua-chu", "2009-09", "2013-07"),
    ("Andrew Yang", "2013-08", "2013-08", {"note": "Resigned within a week"}),
    ("Yen Ming", "2013-08", "2015-01"),
    ("Kao Kuang-chi", "2015-01", "2016-05"),
    ("Feng Shih-kuan", "2016-05", "2018-02"),
    ("Yen Teh-fa", "2018-02", "2021-02"),
    ("Chiu Kuo-cheng", "2021-02", "2024-05"),
    ("Wellington Koo (Koo Li-hsiung)", "2024-05", ""),
], (MND_TW, "worldstatesmen", "wikipedia"))

NATION = {
    "id": "TWN",
    "name": "Republic of China (Taiwan)",
    "tier": 2,
    "periods": [
        P("1895-04", "1945-10", "Japanese Taiwan", "colonial_or_occupied", "Taihoku (Taipei)",
          ["revolution", "foreign_occupation"],
          notes="Ceded to Japan by the Treaty of Shimonoseki; Japanese Governor-General. Not playable as a sovereign actor."),
        P("1945-10", "1949-12", "Taiwan Province of the Republic of China", "colonial_or_occupied", "Taipei (national capital Nanjing)",
          ["revolution"], notes="Province of mainland-ruled ROC (see CHN). February 28 Incident 1947."),
        P("1949-12", "1987-07", "ROC on Taiwan: KMT one-party martial-law state", "one_party_state", "Taipei",
          ["death_in_office", "party_congress", "coup"],
          succession="President elected by the National Assembly (members frozen since 1947-48); Chiang Kai-shek re-elected until death; Temporary Provisions suspended term limits. Martial law 1949-05 to 1987-07.",
          notes="Claimed to be the government of all China; UN seat until 1971-10."),
        P("1987-07", "1996-03", "ROC: democratic transition", "semi_presidential_republic", "Taipei",
          ["general_election", "party_congress", "presidential_dismissal"],
          notes="Opposition DPP legalized; National Assembly and Legislative Yuan fully re-elected 1991-92."),
        P("1996-03", "", "ROC (Taiwan): democratic semi-presidential republic", "semi_presidential_republic", "Taipei",
          ["general_election", "term_limit", "impeachment", "no_confidence", "presidential_dismissal"],
          succession="President directly elected for 4 years (max two terms); appoints the Premier without legislative consent since 1997. Legislative Yuan can pass no-confidence against the Premier (president may then dissolve the legislature). Presidential recall/impeachment requires supermajorities.",
          notes="Game: president removable by election/recall/impeachment; premier by presidential dismissal or no-confidence."),
    ],
    "roles": {
        "head_of_state": pres,
        "paramount_leader": kmt,
        "head_of_government": prem,
        "foreign": fm,
        "defense": mnd,
    },
    "role_notes": {
        "head_of_government": "The Premier (President of the Executive Yuan) heads the cabinet, but the President directs foreign, defence and cross-strait policy.",
        "defense": "1949-1954 holders cross-checked only against Wikipedia's list (Yu Ta-wei's 1950-51 tenure was nominal).",
        "finance": "Not covered (tier 2 minimum: heads, foreign, defence).",
        "interior": "Not covered. Under martial law the Taiwan Garrison Command handled internal security.",
        "intelligence": "National Security Bureau (from 1955); directors not listed.",
        "military_chief": "Chief of the General Staff not listed (gap).",
    },
    "uncertain": [
        "MND 1949-1954 holders and Hau Pei-tsun/Chen Li-an boundary (1990 vs 1991) conflict between sources.",
        "Finance, interior, intelligence, military chief not covered for Taiwan.",
    ],
}
