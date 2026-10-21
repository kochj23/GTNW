"""China 1789-2026: Qing Empire, Republic of China (Beiyang and Nationalist), People's Republic of China.
Republic of China on Taiwan after 1949 is a separate module (twn.py)."""
from nations.common import H, P, add_source

GOV_CN = add_source("gov_cn", "Government of the PRC (english.www.gov.cn) / State Council and ministry leadership pages", "https://english.www.gov.cn/")
MFA_CN = add_source("mfa_cn", "Ministry of Foreign Affairs of the PRC: successive ministers", "https://www.fmprc.gov.cn/eng/")
MOD_CN = add_source("mod_cn", "PRC Ministry of National Defense", "http://eng.mod.gov.cn/")
CHC = add_source("cambridge_china", "The Cambridge History of China, vols. 10-15 (Qing, Republican and PRC volumes)", "https://www.cambridge.org/core/series/cambridge-history-of-china/")
NEWS26 = add_source("news_2026_pla", "Wire reports (Reuters/AP via Gulf News, The Record) on PRC MND announcement of 2026-01-24 investigation of Zhang Youxia and Liu Zhenli",
                    "https://therecord.media/china-investigates-top-general-purge-senior-military-leaders")

WS = ("worldstatesmen", "rulers")


def L(title, native, rows, sources=WS):
    out = []
    for r in rows:
        kw = r[3] if len(r) > 3 else {}
        out.append(H(r[0], title, r[1], r[2], sources, native, **kw))
    return out


U = {"uncertain": True}

# ---------------- Heads of state ----------------
qing = L("Emperor of the Great Qing", "皇帝 Huángdì", [
    ("Qianlong Emperor (Hongli)", "1735-10", "1796-02", {"note": "Abdicated 1796-02-09 but kept real power as Retired Emperor (Taishang Huang) until death 1799-02-07"}),
    ("Jiaqing Emperor (Yongyan)", "1796-02", "1820-09"),
    ("Daoguang Emperor (Minning)", "1820-10", "1850-02"),
    ("Xianfeng Emperor (Yizhu)", "1850-03", "1861-08"),
    ("Tongzhi Emperor (Zaichun)", "1861-08", "1875-01"),
    ("Guangxu Emperor (Zaitian)", "1875-02", "1908-11", {"note": "Under house arrest after the 1898 coup that ended the Hundred Days' Reform"}),
    ("Xuantong Emperor (Puyi)", "1908-12", "1912-02", {"note": "Abdication edict 1912-02-12"}),
], ("britannica", "worldstatesmen", CHC))
roc_hos = L("President of the Republic of China", "中華民國大總統 / 主席 / 總統", [
    ("Sun Yat-sen", "1912-01", "1912-03", {"note": "Provisional President (Nanjing)"}),
    ("Yuan Shikai", "1912-03", "1916-06", {"note": "Provisional then formal President (1913-10); proclaimed himself Hongxian Emperor 1915-12 to 1916-03; died 1916-06-06"}),
    ("Li Yuanhong", "1916-06", "1917-07", {"note": "Ousted during Zhang Xun's restoration of Puyi (1917-07)"}),
    ("Feng Guozhang", "1917-07", "1918-10", {"acting": True}),
    ("Xu Shichang", "1918-10", "1922-06"),
    ("Li Yuanhong", "1922-06", "1923-06"),
    ("Cao Kun", "1923-10", "1924-11", {"note": "Elected by bribing parliament; deposed in Feng Yuxiang's Beijing coup"}),
    ("Duan Qirui", "1924-11", "1926-04", {"note": "Provisional Chief Executive (臨時執政)"}),
    ("Zhang Zuolin", "1927-06", "1928-06", {"note": "Generalissimo of the Military Government (Beijing); 1926-04 to 1927-06 regency cabinets governed without a head of state", "uncertain": True}),
    ("Tan Yankai", "1928-02", "1928-10", {"note": "Chairman of the Nationalist Government (Nanjing); overlaps the last Beiyang regime"}),
    ("Chiang Kai-shek", "1928-10", "1931-12", {"note": "Chairman of the National Government"}),
    ("Lin Sen", "1931-12", "1943-08", {"note": "Chairman of the National Government (ceremonial); died in office"}),
    ("Chiang Kai-shek", "1943-08", "1948-05", {"note": "Chairman of the National Government"}),
    ("Chiang Kai-shek", "1948-05", "1949-01", {"note": "First President under the 1947 Constitution; 'retired' 1949-01-21"}),
    ("Li Zongren", "1949-01", "1949-12", {"acting": True, "note": "Acting President; left for the U.S. 1949-12. Continuation on Taiwan: see TWN"}),
], ("worldstatesmen", "rulers", "britannica"))
prc_hos = L("Chairman / President of the People's Republic of China", "中央人民政府主席 / 中华人民共和国主席", [
    ("Mao Zedong", "1949-10", "1959-04", {"note": "Chairman of the Central People's Government 1949-54; Chairman of the PRC 1954-09 to 1959-04"}),
    ("Liu Shaoqi", "1959-04", "1968-10", {"note": "Purged in the Cultural Revolution; expelled 1968-10-31, died 1969"}),
    ("Dong Biwu", "1968-10", "1975-01", {"acting": True, "note": "Vice-Chairman acting as head of state (with Song Qingling) after Liu's purge; office abolished by the 1975 Constitution"}),
    ("Zhu De", "1975-01", "1976-07", {"note": "Chairman of the NPC Standing Committee as de facto head of state (no presidency 1975-82)"}),
    ("Ye Jianying", "1978-03", "1983-06", {"note": "Chairman of the NPC Standing Committee as de facto head of state; post vacant 1976-07 to 1978-03"}),
    ("Li Xiannian", "1983-06", "1988-04", {"note": "Presidency restored by the 1982 Constitution"}),
    ("Yang Shangkun", "1988-04", "1993-03"),
    ("Jiang Zemin", "1993-03", "2003-03"),
    ("Hu Jintao", "2003-03", "2013-03"),
    ("Xi Jinping", "2013-03", "", {"note": "Term limits removed by 2018 constitutional amendment; third term from 2023-03"}),
], (GOV_CN, "worldstatesmen", "rulers"))

# ---------------- Paramount leaders ----------------
qing_regents = L("Regent / de facto ruler", "", [
    ("Heshen", "1776", "1799-02", {"note": "Grand Councillor and favourite of Qianlong; de facto chief minister, arrested and forced to suicide by Jiaqing 1799", "uncertain": True}),
    ("Empress Dowagers Cixi and Ci'an (co-regents)", "1861-11", "1873-02", {"note": "'Listening to politics behind the curtain' after the Xinyou Coup; Prince Gong as Prince-Counsellor"}),
    ("Empress Dowagers Cixi and Ci'an (co-regents)", "1875-02", "1881-04", {"note": "Second regency for the Guangxu Emperor; Ci'an died 1881-04"}),
    ("Empress Dowager Cixi", "1881-04", "1889-03", {"note": "Sole regent; Guangxu took personal rule 1889-03 but Cixi remained the real power"}),
    ("Empress Dowager Cixi", "1898-09", "1908-11", {"note": "Resumed rule after the Wuxu coup against the Hundred Days' Reform; died 1908-11-15"}),
    ("Zaifeng, Prince Chun", "1908-12", "1911-12", {"note": "Prince Regent for Puyi; resigned 1911-12-06"}),
], ("britannica", CHC, "worldstatesmen"))
roc_pl = L("Paramount leader (Kuomintang)", "", [
    ("Chiang Kai-shek", "1926-07", "1949-01", {"note": "Commander-in-Chief of the National Revolutionary Army 1926; Director-General (Zongcai) of the KMT from 1938-03; real power regardless of state title"}),
], ("britannica",))
prc_pl = L("Paramount leader / Chairman or General Secretary of the CCP Central Committee", "中国共产党中央委员会主席 / 总书记", [
    ("Mao Zedong", "1949-10", "1976-09", {"note": "CCP Chairman (from 1943/1945) until death 1976-09-09; CMC Chairman"}),
    ("Hua Guofeng", "1976-10", "1981-06", {"note": "CCP Chairman; arrested the Gang of Four 1976-10; sidelined by Deng from 1978-12"}),
    ("Deng Xiaoping", "1978-12", "1989-11", {"note": "Paramount leader without the top party/state post (Vice-Premier; CMC Chairman 1981-06 to 1989-11); influence until death 1997"}),
    ("Hu Yaobang", "1981-06", "1987-01", {"note": "CCP Chairman 1981-06; General Secretary from 1982-09 (chairmanship abolished); forced to resign 1987-01"}),
    ("Zhao Ziyang", "1987-01", "1989-06", {"note": "Acting GS 1987-01, confirmed 1987-11; purged after Tiananmen 1989-06-24"}),
    ("Jiang Zemin", "1989-06", "2002-11", {"note": "General Secretary; CMC Chairman 1989-11 to 2004-09"}),
    ("Hu Jintao", "2002-11", "2012-11", {"note": "General Secretary; CMC Chairman 2004-09 to 2012-11"}),
    ("Xi Jinping", "2012-11", "", {"note": "General Secretary and CMC Chairman; 'core' since 2016; third term from 2022-10"}),
], (GOV_CN, "britannica", "worldstatesmen"))

# ---------------- Heads of government ----------------
qing_hog = L("Prime Minister of the Imperial Cabinet", "內閣總理大臣", [
    ("Yikuang, Prince Qing", "1911-05", "1911-11", {"note": "'Royal Cabinet' dominated by Manchu princes"}),
    ("Yuan Shikai", "1911-11", "1912-02", {"note": "Appointed after the Wuchang Uprising; negotiated the abdication"}),
], ("worldstatesmen", "britannica"))
beiyang_pm = L("Premier of the Republic of China (Beiyang government)", "國務總理", [
    ("Tang Shaoyi", "1912-03", "1912-06"),
    ("Lu Zhengxiang", "1912-06", "1912-09"),
    ("Zhao Bingjun", "1912-09", "1913-07"),
    ("Xiong Xiling", "1913-07", "1914-02"),
    ("Sun Baoqi", "1914-02", "1914-05", {"acting": True}),
    ("Xu Shichang", "1914-05", "1915-12", {"note": "As Secretary of State (國務卿) under Yuan's presidential system"}),
    ("Duan Qirui", "1916-04", "1917-05", {"note": "Lu Zhengxiang and Xu Shichang briefly held office 1915-12 to 1916-04", "uncertain": True}),
    ("Li Jingxi", "1917-06", "1917-07", U),
    ("Duan Qirui", "1917-07", "1917-11"),
    ("Wang Shizhen", "1917-11", "1918-03", U),
    ("Duan Qirui", "1918-03", "1918-10"),
    ("Qian Nengxun", "1918-10", "1919-06"),
    ("Jin Yunpeng", "1919-09", "1920-05", U),
    ("Jin Yunpeng", "1920-08", "1921-12", U),
    ("Liang Shiyi", "1921-12", "1922-01"),
    ("Yan Huiqing (W. W. Yen)", "1922-06", "1922-08", {"note": "Multiple short acting premierships 1922-1926", "uncertain": True}),
    ("Wang Chonghui", "1922-09", "1922-11", U),
    ("Zhang Shaozeng", "1923-01", "1923-06", U),
    ("Sun Baoqi", "1924-01", "1924-07", U),
    ("Gu Weijun (V. K. Wellington Koo)", "1926-10", "1927-06", U),
    ("Pan Fu", "1927-06", "1928-06", {"note": "Last Beiyang premier under Zhang Zuolin", "uncertain": True}),
], ("worldstatesmen", "rulers"))
ey = L("President of the Executive Yuan (Premier)", "行政院院長", [
    ("Tan Yankai", "1928-10", "1930-09", {"note": "Died in office"}),
    ("T. V. Soong (Song Ziwen)", "1930-09", "1930-11", {"acting": True}),
    ("Chiang Kai-shek", "1930-11", "1931-12"),
    ("Sun Fo (Sun Ke)", "1932-01", "1932-01"),
    ("Wang Jingwei", "1932-01", "1935-12", {"note": "Later headed the Japanese-sponsored Reorganized National Government in Nanjing (1940-44)"}),
    ("Chiang Kai-shek", "1935-12", "1938-01"),
    ("H. H. Kung (Kong Xiangxi)", "1938-01", "1939-11"),
    ("Chiang Kai-shek", "1939-11", "1945-05"),
    ("T. V. Soong (Song Ziwen)", "1945-05", "1947-03"),
    ("Zhang Qun", "1947-04", "1948-05"),
    ("Weng Wenhao", "1948-05", "1948-11"),
    ("Sun Fo (Sun Ke)", "1948-11", "1949-03"),
    ("He Yingqin", "1949-03", "1949-06"),
    ("Yan Xishan", "1949-06", "1950-03", {"note": "Continued on Taiwan; see TWN"}),
], ("worldstatesmen", "rulers"))
prc_pm = L("Premier of the State Council", "国务院总理 Guówùyuàn Zǒnglǐ", [
    ("Zhou Enlai", "1949-10", "1976-01", {"note": "Premier of the Government Administration Council 1949-54, then State Council; died 1976-01-08"}),
    ("Hua Guofeng", "1976-02", "1980-09", {"note": "Acting 1976-02, confirmed 1976-04"}),
    ("Zhao Ziyang", "1980-09", "1987-11"),
    ("Li Peng", "1987-11", "1998-03", {"note": "Acting 1987-11, confirmed 1988-04; declared martial law 1989-05"}),
    ("Zhu Rongji", "1998-03", "2003-03"),
    ("Wen Jiabao", "2003-03", "2013-03"),
    ("Li Keqiang", "2013-03", "2023-03"),
    ("Li Qiang", "2023-03", ""),
], (GOV_CN, "worldstatesmen", "rulers"))

# ---------------- Foreign ----------------
qing_fm = L("Head of the Zongli Yamen / Waiwubu (Foreign Office)", "總理各國事務衙門 / 外務部", [
    ("Yixin, Prince Gong", "1861-01", "1884-04", {"note": "Founded the Zongli Yamen; dismissed 1884-04"}),
    ("Yikuang, Prince Qing", "1884-04", "1894-09", U),
    ("Yixin, Prince Gong", "1894-09", "1898-05", {"note": "Recalled during the Sino-Japanese War; died 1898-05"}),
    ("Yikuang, Prince Qing", "1898-05", "1911-05", {"note": "Zongli Yamen replaced by the Waiwubu 1901-07; Prince Qing headed it until the 1911 cabinet", "uncertain": True}),
    ("Liang Dunyan", "1911-05", "1912-02", {"note": "Foreign Minister in the 1911 imperial cabinets; frequently absent (Hu Weide acted)", "uncertain": True}),
], ("britannica", CHC, "worldstatesmen"))
roc_fm = L("Minister of Foreign Affairs (Republic of China)", "外交總長 / 外交部長", [
    ("Wang Chonghui", "1912-01", "1912-03", {"note": "Nanjing provisional government"}),
    ("Lu Zhengxiang", "1912-03", "1912-09"),
    ("Sun Baoqi", "1913-09", "1915-01", U),
    ("Lu Zhengxiang", "1915-01", "1916-05", {"note": "Accepted the Twenty-One Demands 1915", "uncertain": True}),
    ("Lu Zhengxiang", "1917-12", "1920-08", {"note": "Led the delegation to the Paris Peace Conference", "uncertain": True}),
    ("Yan Huiqing (W. W. Yen)", "1920-08", "1922-08", U),
    ("Gu Weijun (V. K. Wellington Koo)", "1922-08", "1924-11", {"note": "Intermittently; with gaps", "uncertain": True}),
    ("Wang Zhengting (C. T. Wang)", "1928-06", "1931-09", {"note": "Nationalist Government; resigned after the Mukden Incident"}),
    ("Gu Weijun (V. K. Wellington Koo)", "1931-11", "1931-12", U),
    ("Luo Wengan", "1932-01", "1933-08"),
    ("Wang Jingwei", "1933-08", "1935-12", {"note": "Concurrently President of the Executive Yuan"}),
    ("Zhang Qun", "1935-12", "1937-03"),
    ("Wang Chonghui", "1937-03", "1941-04"),
    ("Guo Taiqi (Quo Tai-chi)", "1941-04", "1941-12"),
    ("T. V. Soong (Song Ziwen)", "1941-12", "1945-07"),
    ("Wang Shijie", "1945-07", "1948-12"),
    ("Wu Tiecheng", "1948-12", "1949-03", U),
    ("Hu Shih (nominal) / George Yeh acting", "1949-06", "1949-10", {"note": "Hu Shih nominated but declined; Ye Gongchao acting; continued on Taiwan (see TWN)", "uncertain": True}),
], ("rulers", "worldstatesmen"))
prc_fm = L("Minister of Foreign Affairs", "外交部长 Wàijiāo Bùzhǎng", [
    ("Zhou Enlai", "1949-10", "1958-02", {"note": "Concurrently Premier"}),
    ("Chen Yi", "1958-02", "1972-01", {"note": "Sidelined from 1967; died 1972-01-06 (Ji Pengfei acting from 1971)"}),
    ("Ji Pengfei", "1972-01", "1974-11"),
    ("Qiao Guanhua", "1974-11", "1976-12"),
    ("Huang Hua", "1976-12", "1982-11"),
    ("Wu Xueqian", "1982-11", "1988-04"),
    ("Qian Qichen", "1988-04", "1998-03"),
    ("Tang Jiaxuan", "1998-03", "2003-03"),
    ("Li Zhaoxing", "2003-03", "2007-04"),
    ("Yang Jiechi", "2007-04", "2013-03"),
    ("Wang Yi", "2013-03", "2022-12"),
    ("Qin Gang", "2022-12", "2023-07", {"note": "Removed after unexplained month-long disappearance"}),
    ("Wang Yi", "2023-07", "", {"note": "Also Director of the CCP Central Foreign Affairs Commission Office (senior foreign-policy post) since 2022"}),
], (MFA_CN, "rulers", "worldstatesmen"))

# ---------------- Defence ----------------
roc_def = L("Minister of War / Minister of National Defense (ROC)", "軍政部長 / 國防部長", [
    ("He Yingqin", "1930-03", "1944-11", {"note": "Minister of Military Administration (軍政部長)"}),
    ("Chen Cheng", "1944-11", "1946-05", {"note": "Minister of Military Administration"}),
    ("Bai Chongxi", "1946-06", "1948-05", {"note": "First Minister of National Defense"}),
    ("He Yingqin", "1948-05", "1948-12", U),
    ("Xu Yongchang", "1948-12", "1949-03", U),
    ("He Yingqin", "1949-03", "1949-06", {"note": "Concurrently Premier", "uncertain": True}),
    ("Yan Xishan", "1949-06", "1950-03", {"note": "Concurrently Premier", "uncertain": True}),
], ("worldstatesmen", "britannica"))
prc_def = L("Minister of National Defense", "国防部长 Guófáng Bùzhǎng", [
    ("Peng Dehuai", "1954-09", "1959-09", {"note": "Purged at the Lushan Conference"}),
    ("Lin Biao", "1959-09", "1971-09", {"note": "Died in plane crash fleeing to the USSR 1971-09-13"}),
    ("Ye Jianying", "1975-01", "1978-03", {"note": "Post vacant 1971-09 to 1975-01 (Ye Jianying ran the CMC's daily work)"}),
    ("Xu Xiangqian", "1978-03", "1981-03"),
    ("Geng Biao", "1981-03", "1982-11"),
    ("Zhang Aiping", "1982-11", "1988-04"),
    ("Qin Jiwei", "1988-04", "1993-03"),
    ("Chi Haotian", "1993-03", "2003-03"),
    ("Cao Gangchuan", "2003-03", "2008-03"),
    ("Liang Guanglie", "2008-03", "2013-03"),
    ("Chang Wanquan", "2013-03", "2018-03"),
    ("Wei Fenghe", "2018-03", "2023-03"),
    ("Li Shangfu", "2023-03", "2023-10", {"note": "Removed after disappearance; later expelled from the CCP"}),
    ("Dong Jun", "2023-12", ""),
], (MOD_CN, GOV_CN, "worldstatesmen"))

# ---------------- Finance ----------------
roc_fin = L("Minister of Finance (Nationalist Government)", "財政部長", [
    ("T. V. Soong (Song Ziwen)", "1928-01", "1933-10"),
    ("H. H. Kung (Kong Xiangxi)", "1933-10", "1944-11"),
    ("O. K. Yui (Yu Hongjun)", "1944-11", "1948-05"),
    ("Wang Yunwu", "1948-05", "1948-11", {"note": "Gold yuan currency reform 1948-08"}),
    ("Xu Kan", "1948-11", "1949-06", U),
], ("worldstatesmen", "britannica"))
prc_fin = L("Minister of Finance", "财政部长 Cáizhèng Bùzhǎng", [
    ("Bo Yibo", "1949-10", "1953-09"),
    ("Deng Xiaoping", "1953-09", "1954-06"),
    ("Li Xiannian", "1954-06", "1975-01"),
    ("Zhang Jingfu", "1975-01", "1979-08"),
    ("Wu Bo", "1979-08", "1980-08", U),
    ("Wang Bingqian", "1980-08", "1992-09"),
    ("Liu Zhongli", "1992-09", "1998-03"),
    ("Xiang Huaicheng", "1998-03", "2003-03"),
    ("Jin Renqing", "2003-03", "2007-08"),
    ("Xie Xuren", "2007-08", "2013-03"),
    ("Lou Jiwei", "2013-03", "2016-11"),
    ("Xiao Jie", "2016-11", "2018-03"),
    ("Liu Kun", "2018-03", "2023-10"),
    ("Lan Fo'an", "2023-10", ""),
], (GOV_CN, "worldstatesmen"))

# ---------------- Interior / Public security ----------------
prc_mps = L("Minister of Public Security", "公安部长 Gōng'ān Bùzhǎng", [
    ("Luo Ruiqing", "1949-10", "1959-09"),
    ("Xie Fuzhi", "1959-09", "1972-03", {"note": "Died in office"}),
    ("Li Zhen", "1973-06", "1973-10", {"note": "Died in office; dates uncertain", "uncertain": True}),
    ("Hua Guofeng", "1973-10", "1977-03", {"note": "Formally from 1975-01", "uncertain": True}),
    ("Zhao Cangbi", "1977-03", "1983-04"),
    ("Liu Fuzhi", "1983-04", "1985-09"),
    ("Ruan Chongwu", "1985-09", "1987-04"),
    ("Wang Fang", "1987-04", "1990-12"),
    ("Tao Siju", "1990-12", "1998-03"),
    ("Jia Chunwang", "1998-03", "2002-12"),
    ("Zhou Yongkang", "2002-12", "2007-10", {"note": "Later Politburo Standing Committee security chief; jailed for life 2015"}),
    ("Meng Jianzhu", "2007-10", "2012-12"),
    ("Guo Shengkun", "2012-12", "2017-11"),
    ("Zhao Kezhi", "2017-11", "2022-06"),
    ("Wang Xiaohong", "2022-06", ""),
], (GOV_CN, "worldstatesmen"))

# ---------------- Intelligence ----------------
roc_intel = L("Director, Bureau of Investigation and Statistics of the Military Affairs Commission (Juntong)", "軍事委員會調查統計局", [
    ("Dai Li", "1938-08", "1946-03", {"note": "De facto head (deputy director in title); died in plane crash 1946-03-17. Led Chiang's secret service from 1932"}),
    ("Mao Renfeng", "1946-03", "1949-12", {"note": "Successor bureau renamed Bureau of Secrecy Preservation (保密局) 1946", "uncertain": True}),
], ("britannica", CHC))
prc_intel = L("Minister of State Security", "国家安全部长 Guójiā Ānquán Bùzhǎng", [
    ("Ling Yun", "1983-06", "1985-09", {"note": "Ministry created 1983-07; before that, foreign intelligence was run by the CCP Central Investigation Department and Kang Sheng's Social Affairs apparatus"}),
    ("Jia Chunwang", "1985-09", "1998-03"),
    ("Xu Yongyue", "1998-03", "2007-08"),
    ("Geng Huichang", "2007-08", "2016-11"),
    ("Chen Wenqing", "2016-11", "2022-10"),
    ("Chen Yixin", "2022-10", ""),
], (GOV_CN, "worldstatesmen"))

# ---------------- Military chief ----------------
roc_cgs = L("Chief of the General Staff (ROC)", "參謀總長", [
    ("He Yingqin", "1938-01", "1944-12", {"note": "Chief of the General Staff of the Military Affairs Commission", "uncertain": True}),
    ("Chen Cheng", "1946-06", "1948-05"),
    ("Gu Zhutong", "1948-05", "1950-03", U),
], ("worldstatesmen",))
prc_cgs = L("Chief of the PLA General Staff / Chief of the Joint Staff Department", "总参谋长 / 联合参谋部参谋长", [
    ("Xu Xiangqian", "1949-10", "1954-10", {"note": "Nominal; Nie Rongzhen acting 1950-1954"}),
    ("Su Yu", "1954-10", "1958-10"),
    ("Huang Kecheng", "1958-10", "1959-09"),
    ("Luo Ruiqing", "1959-09", "1965-12", {"note": "Purged"}),
    ("Yang Chengwu", "1966-08", "1968-03", {"acting": True}),
    ("Huang Yongsheng", "1968-03", "1971-09", {"note": "Purged with Lin Biao"}),
    ("Deng Xiaoping", "1975-01", "1976-04", {"note": "Post vacant 1971-75; Deng purged again 1976-04"}),
    ("Deng Xiaoping", "1977-07", "1980-02"),
    ("Yang Dezhi", "1980-02", "1987-11"),
    ("Chi Haotian", "1987-11", "1992-10"),
    ("Zhang Wannian", "1992-10", "1995-12"),
    ("Fu Quanyou", "1995-12", "2002-11"),
    ("Liang Guanglie", "2002-11", "2007-08"),
    ("Chen Bingde", "2007-09", "2012-10"),
    ("Fang Fenghui", "2012-10", "2017-08", {"note": "General Staff became the CMC Joint Staff Department 2016-01"}),
    ("Li Zuocheng", "2017-08", "2022-10"),
    ("Liu Zhenli", "2022-10", "2026-01", {"note": "Placed under investigation (MND announcement 2026-01-24); successor not confirmed in sources consulted", "uncertain": True}),
], (MOD_CN, "worldstatesmen", NEWS26))

NATION = {
    "id": "CHN",
    "name": "China (Qing Empire / Republic of China / People's Republic of China)",
    "tier": 1,
    "periods": [
        P("1789", "1912-02", "Great Qing Empire", "absolute_monarchy", "Beijing",
          ["death_in_office", "abdication", "revolution", "coup", "family_council"],
          succession="Hereditary; the emperor secretly designated an heir (from Yongzheng's time). Minor emperors ruled through regents (Cixi). The Grand Council (軍機處) and Six Boards formed the inner government; no prime minister until the 1911 cabinet.",
          notes="Opium Wars (1839-42, 1856-60), Taiping Rebellion (1850-64), Self-Strengthening, Sino-Japanese War (1894-95), Boxer Uprising (1900), late-Qing constitutional reforms (1906-11). Ended by the Xinhai Revolution. Game: removal of the player = revolution or palace coup (1861 Xinyou, 1898 Wuxu)."),
        P("1912-01", "1928-06", "Republic of China: Beiyang (Beijing) government", "presidential_republic", "Beijing (Nanjing provisional government 1912-01 to 1912-04)",
          ["coup", "presidential_dismissal", "no_confidence", "revolution"],
          succession="Presidents elected by the National Assembly (often coerced or bribed); premiers needed parliamentary approval but changed with warlord fortunes. Real power with Beiyang warlord cliques (Anhui, Zhili, Fengtian) from 1916.",
          notes="Warlord era; frequent coups. Rival southern (Guangzhou) governments under Sun Yat-sen 1917-25. Game: treat as fragmented; coups common."),
        P("1928-06", "1949-12", "Republic of China: Nationalist (Kuomintang) Government", "one_party_state", "Nanjing (wartime capital Chongqing 1937-11 to 1946-05)",
          ["coup", "revolution", "foreign_occupation", "party_congress"],
          succession="KMT 'political tutelage': the party Central Executive Committee appointed the National Government. 1947 Constitution introduced an elected president (by the National Assembly) from 1948.",
          notes="Japanese invasion 1937-45; Civil War with the CCP 1945-49. Xi'an Incident 1936 (Chiang kidnapped). Japanese puppet regimes (Manchukuo 1932-45, Wang Jingwei 1940-45) not modeled. Government retreated to Taipei 1949-12 (see TWN)."),
        P("1949-10", "1966-05", "People's Republic of China (early Mao era)", "one_party_communist_state", "Beijing",
          ["party_congress", "death_in_office", "coup"],
          succession="CCP Chairman (Mao) supreme; state posts filled by the National People's Congress on party nomination.",
          notes="Korean War, First Five-Year Plan, Great Leap Forward (1958-62)."),
        P("1966-05", "1976-10", "PRC: Cultural Revolution", "one_party_communist_state", "Beijing",
          ["party_congress", "death_in_office", "coup"],
          succession="Mao's personal authority; designated successors purged (Liu Shaoqi 1968, Lin Biao 1971). State presidency vacant from 1968 and abolished 1975.",
          notes="Ended with Mao's death and the arrest of the Gang of Four (1976-10, effectively a palace coup)."),
        P("1976-10", "", "PRC: Reform era (post-Mao)", "one_party_communist_state", "Beijing",
          ["party_congress", "death_in_office", "coup", "revolution"],
          succession="General Secretary chosen by the Central Committee at party congresses (every 5 years) after Politburo Standing Committee consensus; state president and premier elected by the NPC. Term limits (1982) removed for the presidency in 2018.",
          notes="Game: the player is the General Secretary; removal = Politburo/Central Committee vote (Hu Yaobang 1987, Zhao Ziyang 1989) or mass unrest. No no-confidence vote."),
    ],
    "roles": {
        "head_of_state": qing + roc_hos + prc_hos,
        "paramount_leader": qing_regents + roc_pl + prc_pl,
        "head_of_government": qing_hog + beiyang_pm + ey + prc_pm,
        "foreign": qing_fm + roc_fm + prc_fm,
        "defense": roc_def + prc_def,
        "finance": roc_fin + prc_fin,
        "interior": prc_mps,
        "intelligence": roc_intel + prc_intel,
        "military_chief": roc_cgs + prc_cgs,
    },
    "role_notes": {
        "head_of_government": "Qing (to 1911): no head of government in the modern sense. The emperor ruled through the Grand Council (軍機處); its leading Grand Councillor is the closest analogue (e.g. Heshen under Qianlong, Prince Gong 1861-84, Prince Li/Shiduo 1884-1898, Ronglu 1898-1903) but the list is not modeled. Powerful regional viceroys such as Li Hongzhang (Zhili, 1870-95, 1900-01) and Zeng Guofan effectively ran diplomacy and military modernization. PRC: Premier of the State Council (government), under the party General Secretary (see paramount_leader).",
        "paramount_leader": "Use paramount_leader as the player's office for Qing regencies (Cixi), the KMT era (Chiang Kai-shek) and the PRC (CCP Chairman/General Secretary, plus Deng Xiaoping 1978-89 who held no top formal post).",
        "foreign": "Qing: before 1861 diplomacy was handled by the Board of Rites, the Lifanyuan (Court of Colonial Affairs) and Canton officials; Zongli Yamen 1861-1901, Waiwubu 1901-11. Beiyang foreign ministers changed very frequently; list is partial.",
        "defense": "Qing Board of War (兵部) presidents and the 1906 Ministry of the Army not modeled. Beiyang Ministers of War not modeled (power lay with warlords). PRC: the Minister of National Defense is largely a diplomatic/administrative post; real command lies with the CCP Central Military Commission Chairman (Mao, Hua, Deng, Jiang, Hu, Xi).",
        "finance": "Qing Board of Revenue (戶部) presidents and Beiyang finance ministers not modeled (gap).",
        "interior": "Qing Board of Civil Appointments / 1906 Ministry of Civil Affairs, Beiyang and Nationalist Ministers of the Interior not modeled (gap). PRC: Minister of Public Security used as interior/police chief (the Ministry of Civil Affairs is a minor welfare portfolio).",
        "intelligence": "Nationalist era: two services, Juntong (military, Dai Li) and Zhongtong (party, CC Clique/Xu Enzeng); only Juntong listed. PRC before 1983: Central Investigation Department (foreign) and Kang Sheng's security apparatus; Minister of State Security from 1983.",
        "military_chief": "Qing: no general staff until the 1906-1911 reforms; armies commanded by viceroys (Hunan/Huai/Beiyang armies). PRC: Chief of the General Staff (to 2016) / Joint Staff Department (from 2016); real authority is the CMC Chairman and Vice-Chairmen.",
    },
    "uncertain": [
        "Beiyang-era premiers and foreign ministers 1916-1928: very frequent turnover, acting tenures; dates marked uncertain and list is not exhaustive.",
        "Qing Zongli Yamen/Waiwubu leadership after 1884 approximate.",
        "PRC finance minister Wu Bo (1979-80) and Public Security ministers 1972-1977 need confirmation.",
        "PLA Joint Staff chief after Liu Zhenli's 2026-01 removal: successor not confirmed.",
        "Nationalist-era defence/finance holders in 1948-49 collapse uncertain.",
    ],
}
