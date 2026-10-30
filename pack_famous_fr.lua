-- Pack de narration « Village célèbre » : le village classique, peuplé de célébrités
-- (chaque joueur reçoit aussi un alias célèbre). Posé sur content_fr.lua.
return {
    narr = {
        night_start = {
            "La nuit tombe sur le village le plus célèbre de l'Histoire. Même Napoléon doit dormir. Fermez les yeux !",
            "Molière range sa plume, Mozart referme son piano. Le village s'endort.",
            "Einstein éteint la lumière du labo : le temps est relatif, l'heure du coucher, non. Yeux fermés !",
            "Cléopâtre souffle ses bougies, Sherlock Holmes range sa pipe. Bonne nuit, les célébrités.",
            "Le village des légendes va se coucher. Fermez les yeux, gens illustres.",
        },
        dawn = {
            "Bonjour ! Marie Curie est déjà au labo, et le village s'éveille sur un nouveau mystère.",
            "Le soleil se lève sur le village des célébrités. Une gloire n'a pas survécu à la nuit.",
            "L'aube pointe. Charlie Chaplin fait tourner sa canne, Elvis recoiffe sa banane, et tout le monde se compte.",
            "Bonjour, les légendes. Les journaux attendent leur gros titre.",
        },
        debate = {
            "Place au débat ! Sherlock Holmes aurait déjà trouvé. À vous de jouer.",
            "Les grands esprits de l'Histoire se réunissent sur la place. Il y a un loup-garou parmi vous, élémentaire !",
            "Que les célébrités se disputent ! Appliquez la méthode d'Hercule Poirot : soupçonnez tout le monde.",
        },
        vote = {
            "Le village des légendes vote. L'Histoire retiendra votre choix.",
            "Levez la main, les célébrités ! Comptez, puis touchez qui quitte le panthéon.",
            "Votez ! Même Jules César a dû affronter le Sénat. Ça s'est mal fini pour lui.",
        },
        wolves = {
            "Les loups-garous se réveillent. La célébrité ne les impressionne pas : ce soir, une star est au menu.",
            "La meute ouvre les yeux. Qui fera le gros titre tragique de demain ?",
            "Les loups-garous choisissent une victime. Les autographes ne sont pas acceptés comme pot-de-vin.",
        },
        seer = {
            "La voyante se réveille, plus mystérieuse que le sourire de la Joconde. Quel secret cette nuit ?",
            "La voyante ouvre les yeux. Nostradamus en serait jaloux.",
        },
    },

    night_deaths = {
        "Au petit matin, plus de trace de %1. Sherlock Holmes mène l'enquête, mais un peu tard.",
        "%1 ne finira pas ses mémoires. Les éditeurs sont effondrés.",
        "%1 entre au grand musée de l'Histoire. Aile « fins tragiques ».",
        "Une plaque sera posée en l'honneur de %1 : « Ici vécut %1, croqué par les loups. »",
        "%1 était plus célèbre que les loups. Les loups s'en fichaient.",
        "Même Napoléon n'aurait pas pu défendre la maison de %1 cette nuit.",
        "Les fans de %1 se rassemblent devant la maison vide, bougies à la main.",
        "Einstein a calculé les chances de survie de %1. Elles étaient nulles.",
        "Le portrait de %1, peint hier, est devenu un mémorial.",
        "Marie Curie a examiné les lieux : aucune radioactivité, juste beaucoup de dents. Adieu, %1.",
        "La statue de cire de %1 survit au musée Grévin. L'original, hélas, non.",
        "%1 entre dans les livres d'Histoire, à la lettre D comme « dévoration ».",
        "Victor Hugo écrit déjà « Les Misérables, tome 2 : la fin de %1 ».",
        "Les paparazzis sont déçus : la dernière photo de %1 ne montre que deux pattes.",
        "L'autographe de %1 vient de tripler de valeur.",
        "Agatha Christie aurait appelé ça « Meurtre au village ». Victime : %1.",
        "%1 ne sera pas au gala de ce soir. Le tapis rouge est tout triste.",
        "%1 avait promis un rappel. Il n'y aura pas de rappel.",
        "Léonard de Vinci a dessiné les empreintes devant chez %1. Fascinant, et fatal.",
        "L'Histoire se souviendra de %1. Les loups se souviennent déjà du goût.",
    },
    vote_deaths = {
        "Comme Napoléon à Sainte-Hélène, %1 part en exil.",
        "Le vote désigne %1. Le village déchire ses cartes du fan-club.",
        "%1 quitte le panthéon sous l'escorte d'une foule de célébrités en colère.",
        "Tu quoque, village ? %1 reçoit le vote dans le dos.",
        "Bannissement de %1, comme une étoile déchue. La presse people adore.",
        "%1 salue une dernière fois et quitte la scène. Pas d'applaudissements.",
        "Le village efface %1 de ses tablettes. Définitivement.",
        "Exil sur une île déserte pour %1, façon Robinson Crusoé.",
        "L'étoile de %1 sur le Walk of Fame est retirée cet après-midi.",
        "%1 s'en va en murmurant « L'Histoire me jugera ». L'Histoire est occupée.",
    },
    no_deaths = {
        "Personne n'est mort ! Même les loups voulaient des autographes, apparemment.",
        "Toutes les célébrités se réveillent en vie. La presse s'ennuie.",
        "Nuit calme chez les stars. Pas même un scandale.",
        "Personne n'a été mangé. La célébrité doit avoir mauvais goût.",
        "Toutes les légendes sont là. Les livres d'Histoire restent fermés aujourd'hui.",
    },
    mayor_elected = {
        "%1 prend la mairie ! Son portrait sera accroché à côté de la Joconde.",
        "Le village sacre %1 maire, façon Napoléon, avec moins de drame.",
    },
    win = {
        village = { "Le village des légendes gagne ! Chaque survivant aura sa statue sur la place." },
        wolves = { "Les loups-garous gagnent ! L'Histoire retiendra les loups les plus célèbres de tous les temps." },
    },
}
