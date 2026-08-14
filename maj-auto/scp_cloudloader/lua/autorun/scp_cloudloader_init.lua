-- SCP Cloud Loader — point d'entrée
-- Pour les hébergeurs sans accès aux commandes : cet addon, déposé UNE FOIS
-- dans addons/, télécharge la dernière version de l'armurerie depuis GitHub
-- à chaque démarrage du serveur et l'exécute (cache local en secours).

if SERVER then
	AddCSLuaFile("scp_cloudloader/sh_runner.lua")
	AddCSLuaFile("scp_cloudloader/cl_loader.lua")

	include("scp_cloudloader/sh_runner.lua")
	include("scp_cloudloader/sv_loader.lua")
else
	include("scp_cloudloader/sh_runner.lua")
	include("scp_cloudloader/cl_loader.lua")
end
