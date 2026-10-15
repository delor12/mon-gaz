# Guide de Calibration et d'Étalonnage Pas à Pas

Ce guide permet d'étalonner avec précision la cellule de pesée HX711 et le capteur de gaz MQ-6 du boîtier **SmartGas**.

---

## 1. Étalonnage de la Cellule de Pesée (HX711)

L'amplificateur HX711 convertit la déformation physique des jauges en une valeur numérique entière brute 24 bits (typiquement entre 0 et 16 millions). La conversion en kilogrammes suit l'équation affine :

$$\text{Poids (kg)} = \frac{\text{Lecture Brute} - \text{Offset de Tare}}{\text{Facteur d'Échelle (ticks/kg)}}$$

### Matériel Requis :
- Le plateau mécanique assemblé avec la cellule de charge fixée solidement.
- Une masse étalon connue (ex: une bouteille d'eau de 5.00 kg pesée au préalable sur une balance de cuisine précise, ou un disque d'haltère de 5 kg ou 10 kg).

---

### Étape 1 : Mise à Zéro (Tare du Plateau Vide)
1. Assurez-vous que le plateau de la balance est **totalement vide** et stable (aucun câble ne touche le plateau, pas de vibration).
2. Lancez l'application mobile, l'application web ou utilisez `curl` :
   ```bash
   curl -X POST http://smartgas.local/api/v1/tare \
     -H "Authorization: Bearer <VOTRE_JETON>"
   ```
3. L'ESP32 enregistre la valeur brute moyenne comme nouvel `Offset de Tare` dans sa mémoire flash NVS :
   ```json
   {
     "success": true,
     "tare_offset": 8412530,
     "message": "Tare effectuee avec succes"
   }
   ```
4. L'écran TFT et l'application affichent désormais **0.00 kg**.

---

### Étape 2 : Étalonnage avec la Masse de Référence
1. Déposez délicatement la masse connue (ex: **5.00 kg**) au centre du plateau.
2. Attendez 3 à 5 secondes que la lecture se stabilise.
3. Envoyez la commande de calibration :
   ```bash
   curl -X POST http://smartgas.local/api/v1/calibrate \
     -H "Authorization: Bearer <VOTRE_JETON>" \
     -H "Content-Type: application/json" \
     -d '{"known_weight_kg": 5.0}'
   ```
4. L'ESP32 calcule automatiquement le ratio :
   $$\text{calibration\_scale} = \frac{\text{Lecture Brute} - \text{tare\_offset}}{5.0}$$
   et le sauvegarde de façon permanente en NVS.
5. L'ESP32 répond :
   ```json
   {
     "success": true,
     "calibration_factor": -22450.5,
     "measured_weight_kg": 5.000
   }
   ```

---

### Résolution des Problèmes de Pesée (Troubleshooting) :
- **Le poids devient négatif lorsqu'on appuie sur le plateau** :
  - *Cause* : La cellule de pesée est montée à l'envers ou les fils de signal $A+$ et $A-$ sont inversés.
  - *Solution* : Inversez les broches $A+$ (Vert) et $A-$ (Blanc) sur le bornier du HX711, ou multipliez le `calibration_factor` par $-1$.
- **Le poids fluctue de $\pm 100$ grammes en continu (bruit)** :
  - *Cause* : Mauvaise qualité du 5V d'alimentation ou câbles HX711 trop longs agissant comme des antennes.
  - *Solution* : Utilisez des fils torsadés blindés de moins de 20 cm entre le HX711 et l'ESP32, et ajoutez un condensateur de découplage de $100\,\mu\text{F}$ entre VCC et GND du HX711.

---

## 2. Étalonnage et Préchauffage du Capteur de Gaz MQ-6

Le capteur MQ-6 utilise une couche sensible en dioxyde d'étain ($SnO_2$) chauffée par une résistance interne.

### 2.1. Période de Rodage Initial (Burn-In)
- **Lors de la première utilisation** : Laisser le capteur alimenté en continu pendant **24 heures** dans une pièce bien ventilée pour nettoyer la surface sensible de tout résidu de stockage chimique.
- **Au démarrage quotidien** : Un temps de préchauffage de **30 à 60 secondes** est automatiquement géré par le firmware (`MQ_PREHEAT_SECONDS`). L'écran TFT affiche `[CHAUFFAGE]` et aucune alerte n'est déclenchée pendant cette phase.

### 2.2. Réglage de la Résistance en Air Pur ($R_0$)
1. Placez l'appareil dans un environnement propre garanti sans fuite de gaz (extérieur ou pièce aérée).
2. Vérifiez la concentration affichée : elle doit être comprise entre **40 ppm et 80 ppm** (bruit de fond ambiant naturel).
3. Si la valeur dévie anormalement, ajustez le potentiomètre bleu situé sous la platine du capteur MQ-6 jusqu'à obtenir une sortie analogique stable d'environ 0.4V en air pur.

---

## 3. Test de Fonctionnement et Scénario de Sécurité Contrôlé

Pour valider le bon fonctionnement de l'alarme sans aucun danger :
1. Munissez-vous d'un **briquet à gaz standard**.
2. **NE PAS ALLUMER LA FLAMME**. Appuyez uniquement sur la gâchette pour libérer un mince filet de gaz butane à 5 cm de la grille métallique du capteur MQ-6 pendant 1 seconde.
3. Observez la séquence de sécurité immédiate :
   - En moins de 2 secondes, la concentration dépasse 400 ppm.
   - **Buzzer local** : Déclenchement de la tonalité stridente 2.7 kHz pulsée.
   - **LED Rouge** : Clignotement stroboscopique.
   - **Relais** : Déclenchement audible du relais (coupure de l'électrovanne).
   - **Écran TFT** : Bascule en écran rouge clignotant `! DANGER ! FUITE DE GAZ`.
   - **Application Web/Mobile** : Réception immédiate de l'événement WebSocket et affichage de la bannière d'urgence.
4. Éloignez le briquet et aérez. Dès que le gaz redescend sous 320 ppm (hystérésis), le système revient automatiquement à l'état de surveillance normale.
