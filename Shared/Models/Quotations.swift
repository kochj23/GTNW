//
//  Quotations.swift
//  Global Thermal Nuclear War
//
//  3.20.0: epigraphs from three shelves — the world's sacred texts, science fiction, and military doctrine —
//  matched by subject to every crisis, war, change of government, scenario and ending.
//
//  Accuracy rule: every line is quoted exactly as published. Scripture is from public-domain translations
//  (KJV, JPS 1917, Rodwell's Qur'an 1861, Legge's Tao Te Ching 1891, Müller's Dhammapada 1881); doctrine
//  lines are verbatim sentences from public-domain US military publications. Never paraphrase into quotes.
//  Created by Jordan Koch.
//

import Foundation

enum QuoteKind: String, Codable, CaseIterable {
    case sacred = "Sacred texts"
    case sciFi = "Science fiction"
    case military = "Military doctrine"
}

/// What a quote is about. Crises, wars and endings ask for tags; the best overlap wins.
enum QuoteTag: String, Codable, CaseIterable {
    case war, nuclear, peace, diplomacy, deterrence, escalation, intelligence, deception
    case disaster, mercy, power, coup, occupation, defeat, victory, leadership, economy
    case unrest, uncertainty, apocalypse, alliance, cyber, space, terror, accident, fear
}

struct Quotation: Identifiable, Hashable {
    let text: String
    let source: String
    let kind: QuoteKind
    let tags: Set<QuoteTag>
    var id: String { source + "|" + text.prefix(24) }
}

enum Quotations {

    // MARK: Picking

    /// The best quote for `tags`, stable for a given `seed` (the same crisis always shows the same line).
    /// `kind` restricts the shelf; nil rotates the shelf by seed so all three get airtime.
    static func pick(_ tags: Set<QuoteTag>, seed: String, kind: QuoteKind? = nil) -> Quotation {
        let h = stableHash(seed)
        let shelf = kind ?? QuoteKind.allCases[Int(h % UInt64(QuoteKind.allCases.count))]
        let pool = all.filter { $0.kind == shelf }
        let best = pool.map { ($0, $0.tags.intersection(tags).count) }.max { $0.1 < $1.1 }?.1 ?? 0
        let top = best > 0 ? pool.filter { $0.tags.intersection(tags).count == best } : pool
        return top[Int((h / 7) % UInt64(top.count))]
    }

    /// One from each shelf — sacred, science fiction, military — for endings.
    static func triad(_ tags: Set<QuoteTag>, seed: String) -> [Quotation] {
        QuoteKind.allCases.map { pick(tags, seed: seed + $0.rawValue, kind: $0) }
    }

    /// FNV-1a: Swift's hashValue is randomised per launch, which would make a crisis's quote change on reload.
    static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return h
    }

    /// One line for the ticker / log: “"text" — source”.
    static func line(_ q: Quotation) -> String { "“\(q.text)” — \(q.source)" }

    // MARK: The library

    static let all: [Quotation] = sacred + sciFi + military

    static let sacred: [Quotation] = [
        Quotation(text: "And he shall judge among the nations, and shall rebuke many people: and they shall beat their swords into plowshares, and their spears into pruninghooks: nation shall not lift up sword against nation, neither shall they learn war any more.",
                  source: "Isaiah 2:4 (KJV)", kind: .sacred, tags: [.peace, .war, .victory, .diplomacy]),
        Quotation(text: "Blessed are the peacemakers: for they shall be called the children of God.",
                  source: "Matthew 5:9 (KJV)", kind: .sacred, tags: [.peace, .diplomacy, .victory]),
        Quotation(text: "Blessed are the merciful: for they shall obtain mercy.",
                  source: "Matthew 5:7 (KJV)", kind: .sacred, tags: [.mercy, .disaster]),
        Quotation(text: "And ye shall hear of wars and rumours of wars: see that ye be not troubled: for all these things must come to pass, but the end is not yet.",
                  source: "Matthew 24:6 (KJV)", kind: .sacred, tags: [.war, .uncertainty, .fear, .escalation]),
        Quotation(text: "And I looked, and behold a pale horse: and his name that sat on him was Death, and Hell followed with him.",
                  source: "Revelation 6:8 (KJV)", kind: .sacred, tags: [.apocalypse, .nuclear, .defeat]),
        Quotation(text: "But the day of the Lord will come as a thief in the night; in the which the heavens shall pass away with a great noise, and the elements shall melt with fervent heat, the earth also and the works that are therein shall be burned up.",
                  source: "2 Peter 3:10 (KJV)", kind: .sacred, tags: [.apocalypse, .nuclear, .accident]),
        Quotation(text: "Put up again thy sword into his place: for all they that take the sword shall perish with the sword.",
                  source: "Matthew 26:52 (KJV)", kind: .sacred, tags: [.war, .escalation, .defeat, .coup]),
        Quotation(text: "For by wise counsel thou shalt make thy war: and in multitude of counsellors there is safety.",
                  source: "Proverbs 24:6 (KJV)", kind: .sacred, tags: [.leadership, .alliance, .war, .intelligence]),
        Quotation(text: "He maketh wars to cease unto the end of the earth; he breaketh the bow, and cutteth the spear in sunder; he burneth the chariot in the fire.",
                  source: "Psalm 46:9 (KJV)", kind: .sacred, tags: [.peace, .victory]),
        Quotation(text: "Therefore will not we fear, though the earth be removed, and though the mountains be carried into the midst of the sea; Though the waters thereof roar and be troubled, though the mountains shake with the swelling thereof.",
                  source: "Psalm 46:2–3 (KJV)", kind: .sacred, tags: [.disaster, .fear]),
        Quotation(text: "And the rain descended, and the floods came, and the winds blew, and beat upon that house; and it fell not: for it was founded upon a rock.",
                  source: "Matthew 7:25 (KJV)", kind: .sacred, tags: [.disaster]),
        Quotation(text: "A time to love, and a time to hate; a time of war, and a time of peace.",
                  source: "Ecclesiastes 3:8 (KJV)", kind: .sacred, tags: [.war, .peace]),
        Quotation(text: "The race is not to the swift, nor the battle to the strong, neither yet bread to the wise, nor yet riches to men of understanding, nor yet favour to men of skill; but time and chance happeneth to them all.",
                  source: "Ecclesiastes 9:11 (KJV)", kind: .sacred, tags: [.uncertainty, .economy, .defeat]),
        Quotation(text: "Or what king, going to make war against another king, sitteth not down first, and consulteth whether he be able with ten thousand to meet him that cometh against him with twenty thousand?",
                  source: "Luke 14:31 (KJV)", kind: .sacred, tags: [.war, .leadership, .deterrence]),
        Quotation(text: "Then said Jesus unto him, Go, and do thou likewise.",
                  source: "Luke 10:37 (KJV), the Good Samaritan", kind: .sacred, tags: [.mercy, .disaster]),
        Quotation(text: "For I was an hungred, and ye gave me meat: I was thirsty, and ye gave me drink: I was a stranger, and ye took me in.",
                  source: "Matthew 25:35 (KJV)", kind: .sacred, tags: [.mercy, .disaster]),
        Quotation(text: "Rejoice with them that do rejoice, and weep with them that weep.",
                  source: "Romans 12:15 (KJV)", kind: .sacred, tags: [.mercy, .alliance]),
        Quotation(text: "He changeth the times and the seasons: he removeth kings, and setteth up kings.",
                  source: "Daniel 2:21 (KJV)", kind: .sacred, tags: [.power, .coup, .occupation]),
        Quotation(text: "When the righteous are in authority, the people rejoice: but when the wicked beareth rule, the people mourn.",
                  source: "Proverbs 29:2 (KJV)", kind: .sacred, tags: [.power, .coup, .unrest]),
        Quotation(text: "And if a kingdom be divided against itself, that kingdom cannot stand.",
                  source: "Mark 3:24 (KJV)", kind: .sacred, tags: [.unrest, .coup, .alliance]),
        Quotation(text: "Pride goeth before destruction, and an haughty spirit before a fall.",
                  source: "Proverbs 16:18 (KJV)", kind: .sacred, tags: [.defeat, .escalation, .power]),
        Quotation(text: "For what shall it profit a man, if he shall gain the whole world, and lose his own soul?",
                  source: "Mark 8:36 (KJV)", kind: .sacred, tags: [.victory, .occupation, .economy]),
        Quotation(text: "Am I my brother’s keeper?",
                  source: "Genesis 4:9 (KJV)", kind: .sacred, tags: [.mercy, .war, .terror]),
        Quotation(text: "For God hath not given us the spirit of fear; but of power, and of love, and of a sound mind.",
                  source: "2 Timothy 1:7 (KJV)", kind: .sacred, tags: [.fear, .leadership, .terror]),
        Quotation(text: "And he shall judge among many people, and rebuke strong nations afar off; and they shall beat their swords into plowshares, and their spears into pruninghooks: nation shall not lift up a sword against nation, neither shall they learn war any more.",
                  source: "Micah 4:3 (KJV)", kind: .sacred, tags: [.peace, .diplomacy]),
        Quotation(text: "And if they lean to peace, lean thou also to it; and put thy trust in God: for He is the Hearing, the Knowing.",
                  source: "Qur'an 8:61 (Rodwell)", kind: .sacred, tags: [.peace, .diplomacy, .war]),
        Quotation(text: "He who slayeth any one, unless it be a person guilty of manslaughter, or of spreading disorders in the land, shall be as though he had slain all mankind; but that he who saveth a life, shall be as though he had saved all mankind alive.",
                  source: "Qur'an 5:32 (Rodwell)", kind: .sacred, tags: [.mercy, .terror, .nuclear, .disaster]),
        Quotation(text: "Now arms, however beautiful, are instruments of evil omen, hateful, it may be said, to all creatures.",
                  source: "Tao Te Ching 31 (Legge)", kind: .sacred, tags: [.war, .nuclear, .deterrence]),
        Quotation(text: "Calm and repose are what he prizes; victory (by force of arms) is to him undesirable.",
                  source: "Tao Te Ching 31 (Legge)", kind: .sacred, tags: [.victory, .peace]),
        Quotation(text: "For hatred does not cease by hatred at any time: hatred ceases by love, this is an old rule.",
                  source: "Dhammapada 5 (Müller)", kind: .sacred, tags: [.peace, .war, .terror, .unrest]),
        Quotation(text: "If one man conquer in battle a thousand times thousand men, and if another conquer himself, he is the greatest of conquerors.",
                  source: "Dhammapada 103 (Müller)", kind: .sacred, tags: [.victory, .leadership, .occupation]),
        Quotation(text: "Now I am become Death, the destroyer of worlds.",
                  source: "J. Robert Oppenheimer (1965), recalling the Bhagavad Gita", kind: .sacred, tags: [.nuclear, .apocalypse]),
    ]

    static let sciFi: [Quotation] = [
        Quotation(text: "A strange game. The only winning move is not to play.",
                  source: "WOPR, WarGames (1983)", kind: .sciFi, tags: [.nuclear, .peace, .deterrence, .victory]),
        Quotation(text: "Gentlemen, you can't fight in here! This is the War Room!",
                  source: "President Muffley, Dr. Strangelove (1964)", kind: .sciFi, tags: [.war, .escalation, .leadership]),
        Quotation(text: "Of course, the whole point of a Doomsday Machine is lost if you keep it a secret! Why didn't you tell the world, eh?",
                  source: "Dr. Strangelove (1964)", kind: .sciFi, tags: [.deterrence, .nuclear, .intelligence, .accident]),
        Quotation(text: "We're human beings with the blood of a million savage years on our hands. But we can stop it. We can admit that we're killers, but we're not going to kill today.",
                  source: "Captain Kirk, Star Trek, \"A Taste of Armageddon\" (1967)", kind: .sciFi, tags: [.war, .peace, .escalation]),
        Quotation(text: "An old Vulcan proverb: only Nixon could go to China.",
                  source: "Spock, Star Trek VI: The Undiscovered Country (1991)", kind: .sciFi, tags: [.diplomacy, .peace, .power]),
        Quotation(text: "Logic clearly dictates that the needs of the many outweigh the needs of the few.",
                  source: "Spock, Star Trek II: The Wrath of Khan (1982)", kind: .sciFi, tags: [.mercy, .disaster, .leadership]),
        Quotation(text: "Violence is the last refuge of the incompetent.",
                  source: "Salvor Hardin, Isaac Asimov's Foundation (1951)", kind: .sciFi, tags: [.war, .coup, .diplomacy, .terror]),
        Quotation(text: "I must not fear. Fear is the mind-killer.",
                  source: "Litany Against Fear, Frank Herbert's Dune (1965)", kind: .sciFi, tags: [.fear, .uncertainty, .disaster, .terror]),
        Quotation(text: "He who can destroy a thing, controls a thing.",
                  source: "Paul Atreides, Frank Herbert's Dune (1965)", kind: .sciFi, tags: [.power, .deterrence, .economy, .occupation]),
        Quotation(text: "The future's not set. There's no fate but what we make for ourselves.",
                  source: "Terminator 2: Judgment Day (1991)", kind: .sciFi, tags: [.nuclear, .uncertainty, .peace, .cyber]),
        Quotation(text: "Your choice is simple. Join us and live in peace, or pursue your present course and face obliteration.",
                  source: "Klaatu, The Day the Earth Stood Still (1951)", kind: .sciFi, tags: [.deterrence, .peace, .apocalypse]),
        Quotation(text: "You maniacs! You blew it up! Ah, damn you! God damn you all to hell!",
                  source: "Taylor, Planet of the Apes (1968)", kind: .sciFi, tags: [.apocalypse, .defeat, .nuclear]),
        Quotation(text: "All of this has happened before, and all of this will happen again.",
                  source: "Battlestar Galactica (2004)", kind: .sciFi, tags: [.war, .coup, .power, .uncertainty]),
        Quotation(text: "Don't Panic.",
                  source: "Douglas Adams, The Hitchhiker's Guide to the Galaxy (1979)", kind: .sciFi, tags: [.disaster, .fear, .accident, .uncertainty]),
        Quotation(text: "In the moment when I truly understand my enemy, understand him well enough to defeat him, then in that very moment I also love him.",
                  source: "Orson Scott Card, Ender's Game (1985)", kind: .sciFi, tags: [.intelligence, .war, .victory]),
        Quotation(text: "War is good for business.",
                  source: "Ferengi Rule of Acquisition #34, Star Trek: Deep Space Nine", kind: .sciFi, tags: [.economy, .war]),
        Quotation(text: "Peace is good for business.",
                  source: "Ferengi Rule of Acquisition #35, Star Trek: Deep Space Nine", kind: .sciFi, tags: [.economy, .peace, .diplomacy]),
        Quotation(text: "The more you tighten your grip, Tarkin, the more star systems will slip through your fingers.",
                  source: "Princess Leia, Star Wars (1977)", kind: .sciFi, tags: [.occupation, .power, .unrest]),
        Quotation(text: "So this is how liberty dies… with thunderous applause.",
                  source: "Padmé Amidala, Star Wars: Revenge of the Sith (2005)", kind: .sciFi, tags: [.coup, .power]),
        Quotation(text: "I'm sorry, Dave. I'm afraid I can't do that.",
                  source: "HAL 9000, 2001: A Space Odyssey (1968)", kind: .sciFi, tags: [.cyber, .accident, .space]),
        Quotation(text: "We will not go quietly into the night! We will not vanish without a fight!",
                  source: "President Whitmore, Independence Day (1996)", kind: .sciFi, tags: [.war, .defeat, .alliance, .leadership]),
        Quotation(text: "No one would have believed in the last years of the nineteenth century that this world was being watched keenly and closely by intelligences greater than man's.",
                  source: "H. G. Wells, The War of the Worlds (1898)", kind: .sciFi, tags: [.intelligence, .space, .deception]),
        Quotation(text: "It was our last, best hope for peace.",
                  source: "Babylon 5, season one opening narration (1994)", kind: .sciFi, tags: [.diplomacy, .peace, .alliance]),
    ]

    static let military: [Quotation] = [
        Quotation(text: "Deterrence is the practice of discouraging an actor from taking unwanted action.",
                  source: "AFDP 3-0, Operations (USAF)", kind: .military, tags: [.deterrence, .nuclear]),
        Quotation(text: "The fundamental purpose of US nuclear forces is deterrence and in that context, the US uses nuclear weapons every day.",
                  source: "AFDD 2-1.2, Strategic Attack (USAF)", kind: .military, tags: [.deterrence, .nuclear]),
        Quotation(text: "The employment of nuclear weapons may lead to such unintended consequences as escalation of the current conflict or long-term deterioration of relations with other countries.",
                  source: "AFDD 2-1.5, Nuclear Operations (USAF)", kind: .military, tags: [.nuclear, .escalation, .diplomacy]),
        Quotation(text: "Successful NC3 in all environments, including denied access and stressed operating areas, is an essential element to stabilizing a crisis, deterring attack, and maintaining the safety, security, and effectiveness of nuclear operations.",
                  source: "AFDP 3-72, Nuclear Operations (USAF)", kind: .military, tags: [.nuclear, .accident, .cyber, .space]),
        Quotation(text: "Control of US nuclear weapons is established to preclude unauthorized or inadvertent use either by US or allied forces, foreign powers, or terrorists without degrading the operational readiness of these weapons.",
                  source: "AFDD 6-0, Command and Control (USAF)", kind: .military, tags: [.accident, .nuclear, .terror]),
        Quotation(text: "Detecting cyberspace attacks against missile warning and tracking sensors or operations centers may indicate impending missile launches.",
                  source: "SDP 3-103, Missile Warning (USSF)", kind: .military, tags: [.cyber, .space, .accident, .uncertainty]),
        Quotation(text: "The United States is vulnerable to cyberspace attacks by relentless adversaries attempting to infiltrate our networks at work and at home – millions of times a day, 24/7.",
                  source: "AFDD 3-12, Cyberspace Operations (USAF)", kind: .military, tags: [.cyber, .intelligence]),
        Quotation(text: "Complicating this problem is the reality that an enemy’s intentions are normally the product of thought processes different from our own.",
                  source: "MCDP 2, Intelligence (USMC)", kind: .military, tags: [.intelligence, .uncertainty, .deception]),
        Quotation(text: "All decisions must be made in the face of uncertainty.",
                  source: "MCDP 6, Command and Control (USMC)", kind: .military, tags: [.uncertainty, .leadership, .fear]),
        Quotation(text: "The constant potential for chance to influence outcomes in war, combined with the inability to prevent chance from impacting on plans and actions, creates psychological friction.",
                  source: "MCDP 1, Warfighting (USMC)", kind: .military, tags: [.uncertainty, .war, .accident]),
        Quotation(text: "The nature of war carries a combination of fear, uncertainty, ambiguity, chance, horror and, above all, friction that Marines must prepare to counter.",
                  source: "MCDP 7, Learning (USMC)", kind: .military, tags: [.war, .fear]),
        Quotation(text: "Boldness and ruthlessness must be accompanied by strong leadership and tempered by sound judgment.",
                  source: "MCDP 1-3, Tactics (USMC)", kind: .military, tags: [.leadership, .war]),
        Quotation(text: "In difficult situations, the intellect of a military leader is less important than his character.",
                  source: "FMFRP 12-1, Surprise (USMC)", kind: .military, tags: [.leadership, .fear]),
        Quotation(text: "The acts of a man are determined by his character; and to understand or predict the action of a leader or a people their character must be understood.",
                  source: "Small Wars Manual, FMFRP 12-15 (USMC)", kind: .military, tags: [.intelligence, .power, .coup]),
        Quotation(text: "We may use deception to mislead the enemy as to the time and location of our pending attack.",
                  source: "MCDP 1-3, Tactics (USMC)", kind: .military, tags: [.deception, .intelligence]),
        Quotation(text: "The diplomatic instrument uses a nation’s international position combined with diplomacy to achieve national objectives.",
                  source: "MCDP 1-1, Strategy (USMC)", kind: .military, tags: [.diplomacy, .alliance]),
        Quotation(text: "The United States will most likely conduct military operations as part of an alliance or coalition containing allied countries.",
                  source: "MCWP 3-10 (USMC)", kind: .military, tags: [.alliance, .war]),
        Quotation(text: "Small wars are designed to deter war, resolve conflict, promote peace, and support civil authorities in response to domestic crises.",
                  source: "MCWP 5-4, Small Wars (USMC)", kind: .military, tags: [.peace, .unrest, .disaster]),
        Quotation(text: "Historically, forward-deployed naval forces have been quick to respond to an emergency or disaster.",
                  source: "MCWP 3-10 (USMC)", kind: .military, tags: [.disaster, .mercy]),
        Quotation(text: "The US Agency for International Development Office for Foreign Disaster Assistance is usually the initial lead USG agency in a disaster response with DOD in support.",
                  source: "AFDD 4-02, Health Services (USAF)", kind: .military, tags: [.disaster, .mercy, .diplomacy]),
        Quotation(text: "Refugees and displaced persons bring their frustrations, disappointments, fears, and grievances with them.",
                  source: "MCDP 3, Expeditionary Operations (USMC)", kind: .military, tags: [.disaster, .unrest, .mercy]),
        Quotation(text: "A faction that employs a coup d’état seeks to overthrow the governing authority by a quick decisive action by an internal faction within the government.",
                  source: "FM 3-24 / MCWP 3-33.5, Insurgencies and Countering Insurgencies", kind: .military, tags: [.coup, .power]),
        Quotation(text: "The fundamental cause of large-scale resistance movements stems from the dissatisfaction of some portion of the population, whether real, imagined, or incited, with the prevailing political, social, or economic conditions.",
                  source: "FM 31-15, Operations Against Irregular Forces (US Army)", kind: .military, tags: [.unrest, .occupation, .coup]),
        Quotation(text: "It follows from the definition that belligerent occupation must be both actual and effective, that is, the organized resistance must have been overcome and the force in possession must have taken measures to establish its authority.",
                  source: "FM 27-10, The Law of Land Warfare (US Army)", kind: .military, tags: [.occupation, .power, .victory]),
        Quotation(text: "General armistices are usually of a combined political and military character.",
                  source: "FM 27-10, The Law of Land Warfare (US Army)", kind: .military, tags: [.peace, .diplomacy]),
        Quotation(text: "Terrorism is “the calculated use of violence or threat of violence to inculcate fear; intended to coerce or to intimidate governments or societies in the pursuit of goals that are generally political, religious, or ideological.”",
                  source: "MCRP 12-10B.1, quoting Joint Pub 1-02", kind: .military, tags: [.terror, .fear]),
        Quotation(text: "Hence to fight and conquer in all your battles is not supreme excellence; supreme excellence consists in breaking the enemy's resistance without fighting.",
                  source: "Sun Tzu, The Art of War III.2 (Giles)", kind: .military, tags: [.victory, .diplomacy, .deterrence, .peace]),
        Quotation(text: "All warfare is based on deception.",
                  source: "Sun Tzu, The Art of War I.18 (Giles)", kind: .military, tags: [.deception, .intelligence, .war]),
        Quotation(text: "No plan of operations extends with any certainty beyond the first contact with the main hostile force.",
                  source: "Helmuth von Moltke the Elder (1871)", kind: .military, tags: [.war, .uncertainty, .escalation]),
        Quotation(text: "Everything in war is very simple, but the simplest thing is difficult.",
                  source: "Clausewitz, On War I.7, quoted in MCDP 1", kind: .military, tags: [.war, .uncertainty, .accident]),
        Quotation(text: "Thus far the chief purpose of our military establishment has been to win wars. From now on its chief purpose must be to avert them.",
                  source: "Bernard Brodie, The Absolute Weapon (1946)", kind: .military, tags: [.nuclear, .deterrence, .peace]),
        Quotation(text: "Every gun that is made, every warship launched, every rocket fired signifies, in the final sense, a theft from those who hunger and are not fed, those who are cold and are not clothed.",
                  source: "Dwight D. Eisenhower, \"The Chance for Peace\" (1953)", kind: .military, tags: [.economy, .peace, .mercy]),
        Quotation(text: "Mankind must put an end to war—or war will put an end to mankind.",
                  source: "John F. Kennedy, address to the UN General Assembly (1961)", kind: .military, tags: [.nuclear, .apocalypse, .peace, .war]),
        Quotation(text: "A nuclear war cannot be won and must never be fought.",
                  source: "Reagan–Gorbachev joint statement, Geneva (1985)", kind: .military, tags: [.nuclear, .deterrence, .diplomacy, .defeat]),
    ]
}
