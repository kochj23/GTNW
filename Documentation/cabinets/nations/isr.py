"""Israel (1948-2026)."""
from nations.common import H, P, add_source

WS = add_source("ws_isr", "worldstatesmen.org - Israel", "https://www.worldstatesmen.org/Israel.htm")
RU = add_source("rulers_i", "rulers.org - countries I (India, Iran, Israel)", "https://www.rulers.org/ruli.html")
KN = add_source("knesset_gov", "Knesset - Governments of Israel (official)", "https://main.knesset.gov.il/en/mk/government/Pages/default.aspx")
WMFA = add_source("wp_isr_mfa", "Wikipedia - Ministry of Foreign Affairs (Israel), list of ministers (cross-check)", "https://en.wikipedia.org/wiki/Ministry_of_Foreign_Affairs_(Israel)")
WMOD = add_source("wp_isr_mod", "Wikipedia - Ministry of Defense (Israel), list of ministers (cross-check)", "https://en.wikipedia.org/wiki/Ministry_of_Defense_(Israel)")
WMOF = add_source("wp_isr_mof", "Wikipedia - Ministry of Finance (Israel), list of ministers (cross-check)", "https://en.wikipedia.org/wiki/Ministry_of_Finance_(Israel)")
WMOI = add_source("wp_isr_moi", "Wikipedia - Ministry of Interior (Israel), list of ministers (cross-check)", "https://en.wikipedia.org/wiki/Ministry_of_Interior_(Israel)")
MOS = add_source("mossad_gov", "Mossad - Former Directors (official, mossad.gov.il)", "https://www.mossad.gov.il/eng/about/Pages/Former-Directors.aspx")
IDF = add_source("idf_cos", "IDF - Chiefs of the General Staff (official, idf.il)", "https://www.idf.il/en/")
BRI = "britannica"
NEWS26 = add_source("news_isr_2026", "Contemporary press (Times of Israel / JNS / Arab News, 2025-26) for 2025-26 changes", "https://www.timesofisrael.com/")

S = (WS, RU, KN)


def hs(name, frm, to, **kw):
    return H(name, "President of the State of Israel", frm, to, (WS, RU, BRI), native="Nesi HaMedina", **kw)


def pm(name, frm, to, **kw):
    return H(name, "Prime Minister", frm, to, (WS, RU, KN), native="Rosh HaMemshala", **kw)


def fm(name, frm, to, **kw):
    return H(name, "Minister of Foreign Affairs", frm, to, (WMFA, KN, RU), **kw)


def dm(name, frm, to, **kw):
    return H(name, "Minister of Defense", frm, to, (WMOD, KN), native="Sar HaBitahon", **kw)


def fin(name, frm, to, **kw):
    return H(name, "Minister of Finance", frm, to, (WMOF, KN), native="Sar HaOtzar", **kw)


def im(name, frm, to, **kw):
    return H(name, "Minister of the Interior", frm, to, (WMOI, KN), native="Sar HaPnim", **kw)


def mos(name, frm, to, **kw):
    return H(name, "Director of the Mossad", frm, to, (MOS, BRI), native="Rosh HaMossad", **kw)


def cgs(name, frm, to, **kw):
    return H(name, "Chief of the General Staff, IDF", frm, to, (IDF, BRI), native="Ramatkal", **kw)


NATION = {
    "id": "ISR",
    "name": "Israel",
    "tier": 1,
    "periods": [
        P("1948-05", "1949-02", "Provisional Government of Israel", "revolutionary_government", "Tel Aviv",
          ["general_election", "no_confidence"],
          succession="Provisional State Council (Moetzet HaMedina HaZmanit) and Provisional Government governed until the first Knesset convened (14 Feb 1949).",
          notes="War of Independence 1948-49. Weizmann was President of the Provisional State Council."),
        P("1949-02", "1996-06", "State of Israel (parliamentary)", "parliamentary_republic", "Jerusalem (declared capital Jan 1950; Knesset moved Dec 1949). Most foreign embassies stayed in Tel Aviv.",
          ["no_confidence", "general_election", "loss_of_party_leadership"],
          succession="President (elected by the Knesset) asks the MK most likely to form a coalition; government needs Knesset confidence. PM resignation brings down the whole government. Coalition collapse typically leads to Knesset self-dissolution and early elections.",
          notes="Unicameral 120-seat Knesset, pure national-list proportional representation; every government has been a coalition."),
        P("1996-06", "2001-03", "State of Israel (directly elected PM)", "parliamentary_republic", "Jerusalem",
          ["no_confidence", "general_election"],
          succession="PM directly elected (1996, 1999, special PM-only election Feb 2001). A Knesset no-confidence vote (61 MKs) removed the PM but forced new elections for both PM and Knesset.",
          notes="Direct election repealed in 2001 (Basic Law: The Government 2001)."),
        P("2001-03", "", "State of Israel (parliamentary, constructive no-confidence)", "parliamentary_republic", "Jerusalem",
          ["constructive_no_confidence", "general_election", "loss_of_party_leadership"],
          succession="Constructive no-confidence: the Knesset must approve an alternative government (since 2014 amendment) to topple the incumbent. Failure to pass a budget triggers automatic dissolution and elections. Rotation agreements (2020 Netanyahu-Gantz, 2021 Bennett-Lapid) can hand office over without a vote; 'alternate prime minister' post created 2020.",
          notes="Election for the 26th Knesset scheduled for 27 Oct 2026 (Knesset dissolved July 2026); Netanyahu heads the 37th government at the data cut-off."),
    ],
    "roles": {
        "head_of_state": [
            hs("Chaim Weizmann", "1948-05", "1952-11", note="President of the Provisional State Council to 17 Feb 1949; died in office"),
            hs("Yosef Sprinzak", "1952-11", "1952-12", acting=True, note="Knesset Speaker, interim"),
            hs("Yitzhak Ben-Zvi", "1952-12", "1963-04", note="died in office"),
            hs("Kadish Luz", "1963-04", "1963-05", acting=True, note="Knesset Speaker, interim"),
            hs("Zalman Shazar", "1963-05", "1973-05"),
            hs("Ephraim Katzir", "1973-05", "1978-05"),
            hs("Yitzhak Navon", "1978-05", "1983-05"),
            hs("Chaim Herzog", "1983-05", "1993-05"),
            hs("Ezer Weizman", "1993-05", "2000-07", note="resigned"),
            hs("Avraham Burg", "2000-07", "2000-08", acting=True),
            hs("Moshe Katsav", "2000-08", "2007-07", note="suspended from Jan 2007, resigned 1 Jul 2007"),
            hs("Dalia Itzik", "2007-01", "2007-07", acting=True, note="acting during Katsav's suspension and after his resignation"),
            hs("Shimon Peres", "2007-07", "2014-07"),
            hs("Reuven Rivlin", "2014-07", "2021-07"),
            hs("Isaac Herzog", "2021-07", ""),
        ],
        "head_of_government": [
            pm("David Ben-Gurion", "1948-05", "1953-12", note="head of Provisional Government to Mar 1949"),
            pm("Moshe Sharett", "1953-12", "1955-11"),
            pm("David Ben-Gurion", "1955-11", "1963-06"),
            pm("Levi Eshkol", "1963-06", "1969-02", note="died in office"),
            pm("Yigal Allon", "1969-02", "1969-03", acting=True),
            pm("Golda Meir", "1969-03", "1974-06"),
            pm("Yitzhak Rabin", "1974-06", "1977-04"),
            pm("Shimon Peres", "1977-04", "1977-06", acting=True),
            pm("Menachem Begin", "1977-06", "1983-10"),
            pm("Yitzhak Shamir", "1983-10", "1984-09"),
            pm("Shimon Peres", "1984-09", "1986-10", note="national unity rotation government"),
            pm("Yitzhak Shamir", "1986-10", "1992-07"),
            pm("Yitzhak Rabin", "1992-07", "1995-11", note="assassinated 4 Nov 1995"),
            pm("Shimon Peres", "1995-11", "1996-06"),
            pm("Benjamin Netanyahu", "1996-06", "1999-07", note="first directly elected PM"),
            pm("Ehud Barak", "1999-07", "2001-03"),
            pm("Ariel Sharon", "2001-03", "2006-04", note="incapacitated by stroke 4 Jan 2006; declared permanently incapacitated 14 Apr 2006"),
            pm("Ehud Olmert", "2006-01", "2009-03", note="acting PM 4 Jan-14 Apr 2006 (interim to 4 May 2006)"),
            pm("Benjamin Netanyahu", "2009-03", "2021-06"),
            pm("Naftali Bennett", "2021-06", "2022-06", note="rotation agreement with Lapid"),
            pm("Yair Lapid", "2022-07", "2022-12", note="caretaker after Knesset dissolution"),
            pm("Benjamin Netanyahu", "2022-12", ""),
        ],
        "foreign": [
            fm("Moshe Sharett", "1948-05", "1956-06"),
            fm("Golda Meir", "1956-06", "1966-01"),
            fm("Abba Eban", "1966-01", "1974-06"),
            fm("Yigal Allon", "1974-06", "1977-06"),
            fm("Moshe Dayan", "1977-06", "1979-10"),
            fm("Menachem Begin", "1979-10", "1980-03", note="PM held portfolio"),
            fm("Yitzhak Shamir", "1980-03", "1986-10"),
            fm("Shimon Peres", "1986-10", "1988-12"),
            fm("Moshe Arens", "1988-12", "1990-06"),
            fm("David Levy", "1990-06", "1992-07"),
            fm("Shimon Peres", "1992-07", "1995-11"),
            fm("Ehud Barak", "1995-11", "1996-06"),
            fm("David Levy", "1996-06", "1998-01"),
            fm("Benjamin Netanyahu", "1998-01", "1998-10", note="PM held portfolio"),
            fm("Ariel Sharon", "1998-10", "1999-07"),
            fm("David Levy", "1999-07", "2000-08"),
            fm("Shlomo Ben-Ami", "2000-08", "2001-03", note="acting from Aug 2000 (Barak held it briefly)"),
            fm("Shimon Peres", "2001-03", "2002-11"),
            fm("Benjamin Netanyahu", "2002-11", "2003-02"),
            fm("Silvan Shalom", "2003-02", "2006-01"),
            fm("Tzipi Livni", "2006-01", "2009-04"),
            fm("Avigdor Lieberman", "2009-04", "2012-12"),
            fm("Benjamin Netanyahu", "2012-12", "2013-11", note="PM held portfolio during Lieberman's trial"),
            fm("Avigdor Lieberman", "2013-11", "2015-05"),
            fm("Benjamin Netanyahu", "2015-05", "2019-02", note="PM held portfolio"),
            fm("Israel Katz", "2019-02", "2020-05"),
            fm("Gabi Ashkenazi", "2020-05", "2021-06"),
            fm("Yair Lapid", "2021-06", "2022-12", note="also PM from Jul 2022"),
            fm("Eli Cohen", "2022-12", "2024-01"),
            fm("Israel Katz", "2024-01", "2024-11"),
            fm("Gideon Sa'ar", "2024-11", ""),
        ],
        "defense": [
            dm("David Ben-Gurion", "1948-05", "1954-01", note="PM held portfolio"),
            dm("Pinhas Lavon", "1954-01", "1955-02", note="resigned over the Lavon Affair"),
            dm("David Ben-Gurion", "1955-02", "1963-06"),
            dm("Levi Eshkol", "1963-06", "1967-06", note="PM held portfolio until eve of Six-Day War"),
            dm("Moshe Dayan", "1967-06", "1974-06"),
            dm("Shimon Peres", "1974-06", "1977-06"),
            dm("Ezer Weizman", "1977-06", "1980-05"),
            dm("Menachem Begin", "1980-05", "1981-08", note="PM held portfolio"),
            dm("Ariel Sharon", "1981-08", "1983-02", note="resigned after Kahan Commission (Sabra and Shatila)"),
            dm("Menachem Begin", "1983-02", "1983-02", note="PM held portfolio briefly"),
            dm("Moshe Arens", "1983-02", "1984-09"),
            dm("Yitzhak Rabin", "1984-09", "1990-03"),
            dm("Yitzhak Shamir", "1990-03", "1990-06", note="PM held portfolio"),
            dm("Moshe Arens", "1990-06", "1992-07"),
            dm("Yitzhak Rabin", "1992-07", "1995-11", note="PM held portfolio"),
            dm("Shimon Peres", "1995-11", "1996-06", note="PM held portfolio"),
            dm("Yitzhak Mordechai", "1996-06", "1999-01"),
            dm("Moshe Arens", "1999-01", "1999-07"),
            dm("Ehud Barak", "1999-07", "2001-03", note="PM held portfolio"),
            dm("Binyamin Ben-Eliezer", "2001-03", "2002-11"),
            dm("Shaul Mofaz", "2002-11", "2006-05"),
            dm("Amir Peretz", "2006-05", "2007-06"),
            dm("Ehud Barak", "2007-06", "2013-03"),
            dm("Moshe Ya'alon", "2013-03", "2016-05"),
            dm("Benjamin Netanyahu", "2016-05", "2016-05", acting=True),
            dm("Avigdor Lieberman", "2016-05", "2018-11"),
            dm("Benjamin Netanyahu", "2018-11", "2019-11", note="PM held portfolio"),
            dm("Naftali Bennett", "2019-11", "2020-05"),
            dm("Benny Gantz", "2020-05", "2022-12"),
            dm("Yoav Gallant", "2022-12", "2024-11", note="dismissal announced Mar 2023 but rescinded; dismissed Nov 2024"),
            dm("Israel Katz", "2024-11", ""),
        ],
        "finance": [
            fin("Eliezer Kaplan", "1948-05", "1952-06"),
            fin("Levi Eshkol", "1952-06", "1963-06"),
            fin("Pinhas Sapir", "1963-06", "1968-08"),
            fin("Ze'ev Sherf", "1968-08", "1969-12"),
            fin("Pinhas Sapir", "1969-12", "1974-06"),
            fin("Yehoshua Rabinovitz", "1974-06", "1977-06"),
            fin("Simha Erlich", "1977-06", "1979-11"),
            fin("Yigal Hurvitz", "1979-11", "1981-01"),
            fin("Yoram Aridor", "1981-01", "1983-10"),
            fin("Yigal Cohen-Orgad", "1983-10", "1984-09"),
            fin("Yitzhak Moda'i", "1984-09", "1986-04"),
            fin("Moshe Nissim", "1986-04", "1988-12"),
            fin("Shimon Peres", "1988-12", "1990-03"),
            fin("Yitzhak Shamir", "1990-03", "1990-06", note="PM held portfolio"),
            fin("Yitzhak Moda'i", "1990-06", "1992-07"),
            fin("Avraham Shochat", "1992-07", "1996-06"),
            fin("Dan Meridor", "1996-06", "1997-06"),
            fin("Benjamin Netanyahu", "1997-06", "1997-07", note="PM held portfolio"),
            fin("Yaakov Neeman", "1997-07", "1998-12"),
            fin("Benjamin Netanyahu", "1998-12", "1999-02", note="PM held portfolio"),
            fin("Meir Sheetrit", "1999-02", "1999-07"),
            fin("Avraham Shochat", "1999-07", "2001-03"),
            fin("Silvan Shalom", "2001-03", "2003-02"),
            fin("Benjamin Netanyahu", "2003-02", "2005-08", note="resigned over Gaza disengagement"),
            fin("Ehud Olmert", "2005-08", "2006-05", uncertain=True,
                note="sources list his finance term ending Nov 2005 or continuing (as acting/interim PM) until the Olmert government of May 2006"),
            fin("Avraham Hirschson", "2006-05", "2007-04"),
            fin("Ehud Olmert", "2007-04", "2007-07", note="PM held portfolio"),
            fin("Roni Bar-On", "2007-07", "2009-03"),
            fin("Yuval Steinitz", "2009-03", "2013-03"),
            fin("Yair Lapid", "2013-03", "2014-12", note="dismissed"),
            fin("Benjamin Netanyahu", "2014-12", "2015-05", note="PM held portfolio"),
            fin("Moshe Kahlon", "2015-05", "2020-05"),
            fin("Israel Katz", "2020-05", "2021-06"),
            fin("Avigdor Lieberman", "2021-06", "2022-12"),
            fin("Bezalel Smotrich", "2022-12", ""),
        ],
        "interior": [
            im("Yitzhak Gruenbaum", "1948-05", "1949-03"),
            im("Haim-Moshe Shapira", "1949-03", "1952-12"),
            im("Israel Rokach", "1952-12", "1955-06"),
            im("Haim-Moshe Shapira", "1955-06", "1955-11"),
            im("Israel Bar-Yehuda", "1955-11", "1959-12"),
            im("Haim-Moshe Shapira", "1959-12", "1970-07", note="died in office"),
            im("Golda Meir", "1970-07", "1970-09", note="PM held portfolio"),
            im("Yosef Burg", "1970-09", "1974-06"),
            im("Shlomo Hillel", "1974-06", "1974-10"),
            im("Yosef Burg", "1974-10", "1976-12"),
            im("Shlomo Hillel", "1977-01", "1977-06"),
            im("Yosef Burg", "1977-06", "1984-09"),
            im("Shimon Peres", "1984-09", "1984-12", note="PM held portfolio"),
            im("Yitzhak Peretz", "1984-12", "1987-01"),
            im("Yitzhak Shamir", "1987-01", "1988-12", note="PM held portfolio"),
            im("Aryeh Deri", "1988-12", "1993-05"),
            im("Yitzhak Rabin", "1993-05", "1993-06", note="PM held portfolio"),
            im("Aryeh Deri", "1993-06", "1993-09", note="forced out by High Court ruling"),
            im("Yitzhak Rabin", "1993-09", "1995-02", note="PM held portfolio"),
            im("Uzi Baram", "1995-02", "1995-06"),
            im("David Libai", "1995-06", "1995-07"),
            im("Ehud Barak", "1995-07", "1995-11"),
            im("Haim Ramon", "1995-11", "1996-06"),
            im("Eli Suissa", "1996-06", "1999-07"),
            im("Natan Sharansky", "1999-07", "2000-07"),
            im("Haim Ramon", "2000-07", "2001-03"),
            im("Eli Yishai", "2001-03", "2003-02", note="briefly dismissed May-Jun 2002 (Sharon held portfolio)"),
            im("Avraham Poraz", "2003-02", "2004-12"),
            im("Ophir Pines-Paz", "2005-01", "2005-11"),
            im("Ariel Sharon", "2005-11", "2006-05", note="PM held portfolio (Olmert acting from Jan 2006)"),
            im("Roni Bar-On", "2006-05", "2007-07"),
            im("Meir Sheetrit", "2007-07", "2009-03"),
            im("Eli Yishai", "2009-03", "2013-03"),
            im("Gideon Sa'ar", "2013-03", "2014-11"),
            im("Gilad Erdan", "2014-11", "2015-05"),
            im("Silvan Shalom", "2015-05", "2015-12"),
            im("Benjamin Netanyahu", "2015-12", "2016-01", note="PM held portfolio"),
            im("Aryeh Deri", "2016-01", "2021-06"),
            im("Ayelet Shaked", "2021-06", "2022-12"),
            im("Aryeh Deri", "2022-12", "2023-01", note="dismissed after High Court ruling"),
            im("Michael Malchieli", "2023-01", "2023-04", acting=True),
            im("Moshe Arbel", "2023-04", "2025-07", note="resigned when Shas left the government over the draft-exemption law"),
            im("Yariv Levin", "2025-07", "2025-10", acting=True, uncertain=True,
               note="Netanyahu held portfolio briefly in Jul 2025, then Levin as interim; post reported vacant after Oct 2025"),
        ],
        "intelligence": [
            mos("Reuven Shiloah", "1949-12", "1952-09"),
            mos("Isser Harel", "1952-09", "1963-03", note="also oversaw Shin Bet ('Memuneh')"),
            mos("Meir Amit", "1963-03", "1968-09"),
            mos("Zvi Zamir", "1968-09", "1974-09"),
            mos("Yitzhak Hofi", "1974-09", "1982-06"),
            mos("Nahum Admoni", "1982-06", "1989-04"),
            mos("Shabtai Shavit", "1989-04", "1996-06"),
            mos("Danny Yatom", "1996-06", "1998-03"),
            mos("Efraim Halevy", "1998-03", "2002-09"),
            mos("Meir Dagan", "2002-09", "2011-01"),
            mos("Tamir Pardo", "2011-01", "2016-01"),
            mos("Yossi Cohen", "2016-01", "2021-06"),
            mos("David Barnea", "2021-06", "2026-06"),
            H("Roman Gofman", "Director of the Mossad", "2026-06", "", (NEWS26,), native="Rosh HaMossad",
              note="took office 2 Jun 2026; formerly PM's military secretary"),
        ],
        "military_chief": [
            cgs("Yaakov Dori", "1948-05", "1949-11", note="Haganah chief of staff from 1939; IDF from its formation 26 May 1948"),
            cgs("Yigael Yadin", "1949-11", "1952-12"),
            cgs("Mordechai Maklef", "1952-12", "1953-12"),
            cgs("Moshe Dayan", "1953-12", "1958-01"),
            cgs("Haim Laskov", "1958-01", "1961-01"),
            cgs("Tzvi Tzur", "1961-01", "1964-01"),
            cgs("Yitzhak Rabin", "1964-01", "1968-01"),
            cgs("Haim Bar-Lev", "1968-01", "1971-12"),
            cgs("David Elazar", "1972-01", "1974-04", note="resigned after Agranat Commission (Yom Kippur War)"),
            cgs("Mordechai Gur", "1974-04", "1978-04"),
            cgs("Rafael Eitan", "1978-04", "1983-04"),
            cgs("Moshe Levi", "1983-04", "1987-04"),
            cgs("Dan Shomron", "1987-04", "1991-04"),
            cgs("Ehud Barak", "1991-04", "1995-01"),
            cgs("Amnon Lipkin-Shahak", "1995-01", "1998-07"),
            cgs("Shaul Mofaz", "1998-07", "2002-07"),
            cgs("Moshe Ya'alon", "2002-07", "2005-06"),
            cgs("Dan Halutz", "2005-06", "2007-01", note="resigned after 2006 Lebanon War"),
            cgs("Gabi Ashkenazi", "2007-02", "2011-02"),
            cgs("Benny Gantz", "2011-02", "2015-02"),
            cgs("Gadi Eisenkot", "2015-02", "2019-01"),
            cgs("Aviv Kochavi", "2019-01", "2023-01"),
            cgs("Herzi Halevi", "2023-01", "2025-03", note="resigned over 7 October 2023 failures"),
            cgs("Eyal Zamir", "2025-03", ""),
        ],
    },
    "role_notes": {
        "head_of_state": "Ceremonial President elected by the Knesset (7-year single term since 2000; previously 5-year renewable). Pardon power and the mandate to form a government are its main game levers.",
        "head_of_government": "Real executive. 'Alternate Prime Minister' (2020-) is a designated successor under rotation deals: Gantz 2020-21, Lapid 2021-22, Bennett 2022.",
        "intelligence": "Three agencies: Mossad (foreign intelligence, listed here), Shin Bet/Shabak (internal security; directors: Isser Harel 1948-52, Izi Dorot 1952-53, Amos Manor 1953-63, Yosef Harmelin 1964-74, Avraham Ahituv 1974-80, Avraham Shalom 1981-86, Yosef Harmelin 1986-88, Yaakov Peri 1988-95, Carmi Gillon 1995-96, Ami Ayalon 1996-2000, Avi Dichter 2000-05, Yuval Diskin 2005-11, Yoram Cohen 2011-16, Nadav Argaman 2016-21, Ronen Bar Oct 2021-Jun 2025 (dismissal contested in court; resigned), acting deputy 'Sh.' Jun-Oct 2025, David Zini Oct 2025-), and Aman (military intelligence directorate). Mossad and Shin Bet report directly to the PM. Mossad directors' exact month boundaries 1949-1968 are approximate.",
        "defense": "PM frequently holds Defence concurrently (Ben-Gurion, Eshkol, Begin, Rabin, Peres, Barak, Netanyahu).",
        "military_chief": "Ramatkal is the only lieutenant-general; appointed by the cabinet on the defence minister's recommendation, normally 3-4 year terms.",
    },
    "uncertain": [
        "Interior ministry after Oct 2025: reported vacant/held by the PM pending a new appointment; not confirmed as of 2026-10.",
        "27 Oct 2026 Knesset election is after the data cut-off; Netanyahu remains PM (37th government) at cut-off.",
        "Shin Bet acting chief Jun-Oct 2025 is identified publicly only by initial; David Zini start month (Oct 2025) from press reports.",
    ],
}
