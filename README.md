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

Ces scripts font tout en une fois : environnement virtuel `.venv`, dépendances (`install/requirements.txt`), kernel Jupyter `tp_matching_kernel`, **installation d’Elasticsearch en local** (téléchargement, extraction dans `elasticsearch_local/`, démarrage en arrière-plan), **création de l’index `products`** et indexation des 4 produits, puis lancement de Jupyter Lab. En devcontainer, c’est `install/install.sh --no-jupyter` qui est exécuté (Elasticsearch et l’index sont créés aussi).

Pour vérifier à tout moment que **le serveur Elasticsearch est bien joignable et que l’index `products` existe**, vous pouvez exécuter :

```powershell
cd .\TP_matching
.\install\check_elasticsearch.ps1
```

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

## 4. Utilisation avec Elastic Cloud

Pour utiliser un cluster Elasticsearch hébergé (ex. Elastic Cloud), créez un fichier `.env` à la racine de `TP_matching` avec `ES_URL` et `API_KEY`. Vous pouvez coller la clé telle que fournie par Kibana (format `essu_...`) : le script `install/bulk_temp_index.py` enlève le préfixe pour l’en-tête `Authorization: ApiKey`.

Ce même script crée l’index `temp_tp_matching` avec le mapping de la partie Matching **et** peuple cet index cloud avec les produits d’exemple (fichier `install/es_data/products_bulk.ndjson`, enrichi avec quelques produits supplémentaires). Pour l’exécuter :

```powershell
cd .\TP_matching
.\.venv\Scripts\activate
python .\install\bulk_temp_index.py
```

Le script `install/bulk_temp_index.py` lit le bulk NDJSON, remplace l’index `products` par `temp_tp_matching`, crée l’index s’il n’existe pas encore et envoie le bulk vers le cluster défini dans `.env`.

