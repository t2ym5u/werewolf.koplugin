-- "Famous village" narration pack: the classic village, populated by celebrities
-- (every player also gets a famous alias). Laid over content_en.lua.
return {
    narr = {
        night_start = {
            "Night falls on the most famous village in history. Even Napoleon has to sleep. Eyes closed!",
            "Shakespeare puts down his quill, Mozart closes the piano. The village sleeps.",
            "Einstein switches off the lab light: time is relative, but bedtime is not. Eyes shut!",
            "Cleopatra blows out her candles, Sherlock Holmes puts away his pipe. Good night, celebrities.",
            "The village of legends goes to bed. Close your eyes, famous people.",
        },
        dawn = {
            "Morning! Marie Curie is already in the lab, and the village wakes up to a new mystery.",
            "The sun rises over the village of the famous. Somebody's fame did not survive the night.",
            "Dawn breaks. Charlie Chaplin twirls his cane, Elvis fixes his hair, and everyone counts heads.",
            "Good morning, legends. The newspapers are waiting for the headline.",
        },
        debate = {
            "Debate time! Sherlock Holmes would already know. You have to work it out.",
            "The great minds of history gather in the square. Somebody here is a werewolf, elementary!",
            "Let the famous argue! Use Agatha Christie's methods: suspect everyone.",
        },
        vote = {
            "The village of legends votes. History will remember your choice.",
            "Hands up, celebrities! Count the votes and tap who leaves the hall of fame.",
            "Vote! Even Julius Caesar had to face a vote. It went badly for him.",
        },
        wolves = {
            "The werewolves wake up. Fame doesn't impress them: tonight, a celebrity is on the menu.",
            "The pack opens its eyes. Who will be tomorrow's tragic headline?",
            "The werewolves wake and choose a victim. Autographs are not accepted as a bribe.",
        },
        seer = {
            "The seer wakes up, more mysterious than the Mona Lisa's smile. Whose secret tonight?",
            "The seer opens their eyes. Nostradamus would be jealous.",
        },
    },

    night_deaths = {
        "%1 was found at dawn. Sherlock Holmes is on the case, but it's a bit late.",
        "%1 will not finish their memoirs. Publishers are devastated.",
        "%1 joins the great museum of history. In the 'tragic ends' wing.",
        "A plaque will be unveiled in %1's honour. 'Here lived %1, eaten by wolves.'",
        "%1 was more famous than the wolves. The wolves didn't care.",
        "Even Napoleon couldn't have defended %1's house last night.",
        "%1's fans gather outside the empty house with candles.",
        "Einstein calculated %1's chances of survival. They were zero.",
        "%1 had a portrait painted yesterday. It is now a memorial.",
        "Marie Curie examined the scene: no radioactivity, just a lot of teeth. Farewell, %1.",
        "%1's wax figure survives in the museum. The original, sadly, does not.",
        "%1 enters the history books, under 'D' for 'devoured'.",
        "Shakespeare is already writing 'The Tragedy of %1'. Five acts, lots of wolves.",
        "The paparazzi are disappointed: %1's last photo shows only a pair of paws.",
        "%1's autograph has just tripled in value.",
        "Agatha Christie would have called it 'Murder at the Village'. Victim: %1.",
        "%1 will not be at tonight's gala. The red carpet looks sad.",
        "%1 promised an encore. There will be no encore.",
        "Leonardo da Vinci sketched the paw prints outside %1's house. Fascinating, and fatal.",
        "History will remember %1. The wolves already remember the taste.",
    },
    vote_deaths = {
        "Like Napoleon on Elba, %1 is sent into exile.",
        "%1 is voted out. The village tears up the fan club membership cards.",
        "%1 leaves the hall of fame, escorted by an angry crowd of celebrities.",
        "Et tu, village? %1 is stabbed in the back by the vote.",
        "%1 is banished, like a fallen star. The tabloids love it.",
        "%1 takes a final bow and leaves the stage. No applause.",
        "The village cancels %1. Permanently.",
        "%1 is exiled to a desert island, Robinson Crusoe-style.",
        "%1's star on the walk of fame is removed this afternoon.",
        "%1 leaves, muttering 'History will absolve me.' History is busy.",
    },
    no_deaths = {
        "Nobody died! Even the wolves wanted autographs, apparently.",
        "Every celebrity wakes up alive. The press is bored.",
        "A quiet night for the stars. Not even a scandal.",
        "Nobody was eaten. Fame must taste bad.",
        "All legends present. The history books stay closed today.",
    },
    mayor_elected = {
        "%1 is elected mayor! Their portrait will hang next to the Mona Lisa.",
        "The village crowns %1 mayor, Napoleon-style, but with less drama.",
    },
    win = {
        village = { "The village of legends wins! A statue of every survivor will be erected in the square." },
        wolves = { "The werewolves win! History will remember them as the most famous wolves of all time." },
    },
}
