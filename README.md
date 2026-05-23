# Misterix-MTA-SA
Misterix resource for Multi Theft Auto. Inspired by the original Misterix script on MTA resources made by Rhypasa https://community.multitheftauto.com/index.php?p=resources&amp;s=details&amp;id=15163, and by the singleplayer mod. My own take on this.

# Note about AI usage

I don't condone you guys making scripts with AI - it sucks. Hire a scripter and he will do a 1000% better script than this. My dream was to play a way cooler version of misterix than Rhypasa made, because I felt some stuff were missing there, and script weren't updated that often. He only put AI guys around the map and I don't think he even put blips there so far I remember, and they had sooo much HP. I think, it's fair if you use AI to learn scripting, and I scripted few smaller scripts before for my own use (like easy script, which permits people from certain countries to enter the server). I also don't sell it, which to be honest - selling an AI script would be such a dogshit move. But if anyone else, dreamt about this kind of Misterix script (with a lot of features like this) this is for those people who just want to have fun and always wanted to try it. With the help of AI I realized that vision, how a misterix script imo should look like. I hope, despite most of the code being AI - you have fun playing this, privately with your friends. I don't think it's ready for major public use, but I have a server just in case you want to test it out, it's not open most of the times because it's a free server and we had played around for fun with my friend there:

mtasa://51.75.58.35:28778

Feel free to make your own versions of this script, implement any stuff from this script to yours - I'd love to see an actual fully human-made misterix script better than this. What I will try to do is I will try to fetch the music files so instead of grueling 60+ mb file, you will be able to load in quickly to the server because music could be played from Github and fetched.

# Features

- Create your own ped mysteries (with /cm command) - you need to be an admin to do this
- Create car mysteries as well (with separate car ai)
- Skin mods for various peds and music that you can always edit / add in the script
- AI can throw projectiles at you, or fire with projectiles (spraycan still doesn't work, but flame thrower does for example)
- Taxi system for few myths for now (check out the video to know how to make more taxi paths)
- Weapon buying system (for future gamemode)
- Health bars for myths
- Not only 1 peds in one myth, there can be multiple peds (check out Epsilon or Zombies-Nemesis)
- Spawn friendly Yakuza with /yakuza command - they will help you battle the myths. Better spawn them after you accepted the mission, you might seen some glitches like them not getting out of the vehicle. I also tried to make Drive-by (with AI too) and they just seem to have an invisible weapon out of the car window, and they don't shoot with it so yeah, but they get out / get in of the cars, attack the myths, that's enough for me :) They also if there are no car seats left, look for a nearby car and drive it behind you (that's a nice touch I think)
- Save system (saves your skin, money, stats - sometimes muscles do not save or aren't loaded)
- Garage: You can add any vehicle to your garage by typing a command, and then you can retrieve it from the garage by typing /grg and you'll spawn inside of it.

# In which gamemode this script is supposed to be played on?

It should be played on Freeoram now. I planned to make it a separate gamemode, but I don't have a lot of help with it. I only script by myself (small easier stuff), but most of the code is sadly AI (and I feel like I need to disclose that). I edited stuff myself too, and if you are a better scripter you can make this script a lot more better, and you can remake it even better than I did. I wanted that kind-of misterix script to be in MTA:SA, and that one that we played had only few mysteries, which half of them never worked for me and my friend - and this was the dream, that AI helped us to achieve (to play a better version of "misterix") it still has glitches

# You mentioned Plane AI in your video, where is it?

Plane AI didn't work out. I couldn't make planes follow me in the air, or dive bomb and then go up again. I once made Rustler somehow to shoot the weapon at me (that machine gun that rustler has) but that's it. Plane AI always overcomplicates the buttons - it instantly goes forward into a loop in the air and then crashes upside down to the ground, which looks so funny. Or I made it crash into the walls lol. I'd love to make ghost planes a myth in the future, but as I said I never had any help with it so it will probably never be possible, but who knows. It's inside the script plane_ai.lua and plane_ai.old but they are not linked in meta.xml
