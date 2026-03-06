# TP_matching

Ce dépôt contient le matériel d’un TP composé de deux parties indépendantes :
- une **partie Cyber** (tests de connectivité réseau) ;
- une **partie Matching Elasticsearch** (index / requêtes vectorielles).

L’intégralité du TP se fait dans le notebook `tp_elastic_and_matching.ipynb`.

## 1. Installation de l’environnement (local)

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

Ces scripts font tout en une fois : environnement virtuel `.venv`, dépendances (`install/requirements.txt`), kernel Jupyter `tp_matching_kernel`, **installation d’Elasticsearch en local** (téléchargement, extraction dans `elasticsearch_local/`, démarrage en arrière-plan), **création de l’index `products`** et indexation des 4 produits, puis lancement de Jupyter Lab. En devcontainer, c’est `install/install.sh --no-jupyter` qui est exécuté (Elasticsearch et l’index sont créés aussi).

## 2. Utilisation dans un Codespace / devcontainer

Si vous ouvrez ce dépôt dans un Codespace GitHub ou via VS Code Remote qui prend en compte `.devcontainer/devcontainer.json` :
- une image Python 3.11 est utilisée comme base,
- la commande `postCreateCommand` exécute `install/install.sh --no-jupyter` (venv, deps, kernel, Elasticsearch + index),
- l’interpréteur par défaut est le Python du `.venv` créé par le script.

Dans ce cas, à l’ouverture du Codespace vous pouvez directement ouvrir `tp_elastic_and_matching.ipynb` et sélectionner le kernel `tp_matching_kernel`, sans relancer les scripts d’installation locaux.

## 3. Lancer le TP

Une fois l’installation terminée (local ou Codespace), Elasticsearch tourne déjà en local sur http://localhost:9200 avec l’index `products` et les 4 produits :

1. Ouvre `tp_elastic_and_matching.ipynb` dans ton éditeur (Cursor / VS Code / Jupyter Lab).
2. Suis les cellules dans l’ordre :
   - **Section 1** : partie Cyber (exécutée avec un noyau **PowerShell** ou en copiant les commandes dans un terminal PowerShell).
   - **Sections suivantes** : partie Matching avec un noyau **Python** (kernel `tp_matching_kernel` ou équivalent).

