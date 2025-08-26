#!/bin/bash
# ==============================================
# Script de migration Proxmox 6 -> 7 -> 8
# ⚠️ Serveur ancien (old hardware)
#    - Ne supporte pas les noyaux récents (6.x)
#    - Compatible uniquement avec Proxmox basé sur kernel 5.15
#    - On garde pve-kernel-5.15 et on le verrouille
# ==============================================
# Auteur : Malek Ben Attia
# Date   : 26/08/2025
# ==============================================

# --- Étape 1 : Nettoyage anciens dépôts et configuration Buster ---
echo "[*] Nettoyage anciens dépôts..."
rm -f /etc/apt/sources.list.d/pve-enterprise.list
rm -f /etc/apt/sources.list.d/pve-no-subscription.list

echo "[*] Configuration dépôts Debian 10 (Buster) archivés..."
cat > /etc/apt/sources.list <<'EOF'
deb http://archive.debian.org/debian buster main contrib
deb http://archive.debian.org/debian-security buster/updates main contrib
deb http://archive.debian.org/debian buster-updates main contrib
EOF

# Ignorer expiration dépôts archivés
echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99ignore-check-valid-until

# Dépôt Proxmox VE 6 no-subscription (pour serveur ancien)
echo "deb http://download.proxmox.com/debian/pve buster pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list

echo "[*] Mise à jour système (Proxmox 6.x)"
apt update && apt dist-upgrade -y
reboot

# --- Étape 2 : Vérification compatibilité migration 6 -> 7 ---
echo "[*] Vérification migration Proxmox 6 -> 7"
pve6to7 --full

# --- Étape 3 : Migration vers Proxmox 7 ---
echo "[*] Configuration dépôts Debian 11 (Bullseye) archivés..."
cat > /etc/apt/sources.list <<'EOF'
deb http://archive.debian.org/debian bullseye main contrib
deb http://archive.debian.org/debian-security bullseye-security main contrib
deb http://archive.debian.org/debian bullseye-updates main contrib
EOF

echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list

echo "[*] Mise à jour système (Proxmox 7.x)"
apt update && apt dist-upgrade -y
reboot

# --- Étape 4 : Installer et verrouiller kernel 5.15 ---
echo "[*] Installation noyau 5.15 (spécial vieux serveur)..."
apt search pve-kernel
apt install -y pve-kernel-5.15

echo "[*] Verrouillage noyau 5.15 (empêche MAJ vers 6.x non supporté)"
apt-mark hold pve-kernel-5.15

echo "[*] Vérification version noyau..."
uname -r

echo "[*] Vérification compatibilité migration 7 -> 8"
pve7to8 --full

# --- Étape 5 : Migration vers Proxmox 8 ---
echo "[*] Configuration dépôts Debian 12 (Bookworm)..."
cat > /etc/apt/sources.list <<'EOF'
deb http://deb.debian.org/debian bookworm main contrib
deb http://deb.debian.org/debian-security bookworm-security main contrib
deb http://deb.debian.org/debian bookworm-updates main contrib
EOF

echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list

echo "[*] Mise à jour système (Proxmox 8.x)"
apt update && apt dist-upgrade -y
reboot

# --- Étape 6 : Vérifications après migration ---
echo "[*] Vérification version Proxmox et kernel..."
pveversion
uname -r

echo "[*] Nettoyage paquets inutiles..."
apt autoremove --purge -y

# --- Étape 7 : Forcer GRUB à utiliser kernel 5.15 ---
echo "[*] Lister noyaux installés..."
dpkg -l | grep pve-kernel

echo "[*] Vérifier entrées GRUB..."
grep menuentry /boot/grub/grub.cfg | nl -v 0

echo "[*] Modifier /etc/default/grub pour forcer le noyau 5.15, puis exécuter :"
echo 'grub-set-default "Advanced options for Proxmox VE GNU/Linux>Proxmox VE GNU/Linux, with Linux 5.15.158-2-pve"'
update-grub
reboot

# ==============================================
# Fin du script - Migration terminée
# ⚠️ Le serveur reste bloqué sur kernel 5.15
#    car il ne supporte pas les noyaux récents
# ==============================================
