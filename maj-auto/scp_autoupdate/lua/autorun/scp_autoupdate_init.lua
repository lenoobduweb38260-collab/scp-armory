-- SCP AutoUpdate — point d'entrée
-- Tout se passe côté serveur : rien n'est envoyé aux clients.

if SERVER then
	include("scp_autoupdate/sv_autoupdate.lua")
end
