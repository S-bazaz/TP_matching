# TP_matching

Ce dépôt contient le matériel d’un TP composé de deux parties indépendantes :
- une **partie Cyber** (tests de connectivité réseau) ;
- une **partie Matching Elasticsearch** (index / requêtes vectorielles).

L’intégralité du TP se fait dans le notebook `tp_elastic_and_matching.ipynb`.

## 1. Installation de l’environnement (local)

> **Important :** avant d’utiliser la partie Matching avec un cluster Elasticsearch (local **ou** cloud), créez un fichier `.env` à la racine de `TP_matching` contenant au minimum `ES_URL` et `API_KEY` adaptés à votre cluster. Sans ce fichier, les scripts et le notebook ne pourront pas se connecter à Elasticsearch.

Depuis un terminal ouvert à la racine du dépôt `TP_matching` :

- **Sous PowerShell (Windows)** :

```powershell
cd .\TP_matching
.\install\install.ps1
```

- **Sous bash (Linux / macOS / WSL / Git Bash)** :

```bash
cd TP_matching
./install/install.sh
```

Ces scripts font tout en une fois : environnement virtuel `.venv`, dépendances (`install/requirements.txt`), kernel Jupyter `tp_matching_kernel`, puis lancement de Jupyter Lab (sauf si vous passez l’option `--no-jupyter` côté bash). **Ils ne démarrent plus d’instance Elasticsearch locale** : le cluster utilisé pour la partie Matching est celui pointé par votre `.env` (souvent un déploiement Elastic Cloud).

## 2. Utilisation dans un Codespace / devcontainer

Si vous ouvrez ce dépôt dans un Codespace GitHub ou via VS Code Remote qui prend en compte `.devcontainer/devcontainer.json` :
- une image Python 3.11 est utilisée comme base,
- la commande `postCreateCommand` exécute `install/install.sh --no-jupyter` (venv, deps, kernel),
- l’interpréteur par défaut est le Python du `.venv` créé par le script.

Dans ce cas, à l’ouverture du Codespace vous pouvez directement ouvrir `tp_elastic_and_matching.ipynb` et sélectionner le kernel `tp_matching_kernel`, sans relancer les scripts d’installation locaux.

## 3. Lancer le TP

Une fois l’installation terminée (local ou Codespace) :
1. Assurez‑vous que votre fichier `.env` pointe vers un cluster Elasticsearch joignable (`ES_URL`, `API_KEY`).
2. Si nécessaire, créez l’index de travail et injectez les exemples sur ce cluster à l’aide des scripts décrits ci‑dessous (section 4).

Ensuite :
1. Ouvre `tp_elastic_and_matching.ipynb` dans ton éditeur (Cursor / VS Code / Jupyter Lab).
2. Suis les cellules dans l’ordre :
   - **Section 1** : partie Cyber (exécutée avec un noyau **PowerShell** ou en copiant les commandes dans un terminal PowerShell).
   - **Sections suivantes** : partie Matching avec un noyau **Python** (kernel `tp_matching_kernel` ou équivalent).

