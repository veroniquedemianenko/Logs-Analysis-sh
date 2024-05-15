#!/usr/local/bin/bash

fichier_log="/Users/veroniquedemianenko/Desktop/bigdata/auth/logs_utiles.txt" # attention il ne faut pas mettre d'espace

## Pour l'instant j'ai fonctionné avec les fonctions, il faut que je les modifie pour rentrer simplement les -u, -i etc. 

function user_connected() {
    # les lignes de log qui nous intéressent sont celles qui ont disconnected from car on a accès à l'identifiant


    # on créé un fichier temporaire qui ne contient pas les mots Invalid, fichier qu'on supprime ensuite
    fichier_temp=$(mktemp)
    grep -v -i 'invalid' "$fichier_log" > "$fichier_temp"

# On affiche les identifiants contenus dans les lignes "disconnected from" : 
# on lit mot par mot chaque ligne, une fois qu'on atteint la chaine "user", on affiche le mot suivant qui est l'identifiant de l'utilisateur.
    echo "Identifiants des utilisateurs valides déconnectés :"
    awk '/Disconnected from/ {for (i=1; i<=NF; i++) {if ($i == "user") print $(i+1)}}' "$fichier_temp" | sort | uniq


    nb_identifiants=$(awk '/Disconnected from/ {for (i=1; i<=NF; i++) {if ($i == "user") print $(i+1)}}' "$fichier_temp" | sort | uniq | wc -l)
    echo "Nombre total d'identifiants : $nb_identifiants"

# suppression dudit fichier
    rm "$fichier_temp"

}

# après je pourrai écrire sur le terminal ./Analyse.sh user_connected, et ça lancera la fonction u, 
# qui donne les identifiants des utilisateurs ayant réussi à se connecter et, à la fin, 
# leur nombre total  




function user_invalid() { # c'est -u
    
    fichier_temp=$(mktemp)
    grep -i 'invalid' "$fichier_log" > "$fichier_temp" # on ne prend que les lignes contenant Invalid ou invalid


    echo "Identifiants des utilisateurs invalides rejetés :" # on prend les identifiants (pour cela on regarde l'élément suivant "user" et on vérifie bien que ce n'est pas une adresse ip en regardant le premier caractère de la chaine. Si ce n'est pas un chiffre entre 0 et 9, on l'inscrit.)
    awk '{for (i=1; i<=NF; i++) {if ($i == "user" && !(substr($(i+1), 1, 1) ~ /^[0-9]$/)) print $(i+1)}}' "$fichier_temp" | sort | uniq


    nb_identifiants=$(awk '{for (i=1; i<=NF; i++) {if ($i == "user" && !(substr($(i+1), 1, 1) ~ /^[0-9]$/)) print $(i+1)}}' "$fichier_temp" | sort | uniq | wc -l)
    echo "Nombre total d'identifiants rejetés : $nb_identifiants"


    rm "$fichier_temp"

}


function ip_connected() { # c'est -U

    fichier_temp=$(mktemp)
    grep -v -i 'invalid' "$fichier_log" > "$fichier_temp"

    echo "Adresses IP des utilisateurs valides qui se sont connectés:"
    awk '/Received disconnect from/ {for (i=1; i<=NF; i++) {if ($i == "from" && ($(i+1) ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/32)?/)) print $(i+1)}}' "$fichier_temp" | sort | uniq

    rm "$fichier_temp"
}


function ip_invalid() { # c'est -i

    fichier_temp=$(mktemp)
    grep -i 'invalid' "$fichier_log" > "$fichier_temp"

    echo "Adresses IP des utilisateurs invalides qui n'ont pas pu se connecter :"
    awk '{for (i=4; i<=NF-3; i++) {if ($i ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/32)?/) print $i}}' "$fichier_temp" | sort | uniq 

    rm "$fichier_temp"

}


function ip_blocked() { # c'est -I
    fichier_temp=$(mktemp)
    grep -iw 'Blocking' "$fichier_log" > "$fichier_temp"

    echo "Adresses IP des utilisateurs bloqués :" # ici on a donc sélectionné que les logs concernant le blockage, et on n'affiche que les adresses ip
    awk '{ for (i=1; i<=NF; i++) { if ($i ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/32)?/) print $i } }' "$fichier_temp" | sort | uniq 
    
    nb_ip=$(awk '{ for (i=1; i<=NF; i++) { if ($i ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/32)?/) print $i } }' "$fichier_temp" | sort | uniq | wc -l)
    echo "Nombre total d'identifiants rejetés : $nb_ip"

    rm "$fichier_temp"
}


function ip_blocked_temps() {
    fichier_temp=$(mktemp)
    fichier_time=$(mktemp)
    grep -iw 'Blocking' "$fichier_log" > "$fichier_temp"

    awk '{ for (i=1; i<=NF; i++) { if ($i ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/32)?/) print $i, $(i+2), $(i+3) } }' "$fichier_temp" | sort | uniq > "$fichier_time"
    
    declare -A temps_ip

    while IFS= read -r ligne; do
        adresse_ip=$(echo "$ligne" | awk '{print $1}')
        temps=$(echo "$ligne" | awk '{print $2}')

        temps_ip["$adresse_ip"]=$(( ${temps_ip["$adresse_ip"]} + temps ))
    done < "$fichier_time"

    for ip in "${!temps_ip[@]}"; do
    echo "Adresse IP : $ip - Temps total de blocage : ${temps_ip["$ip"]} secs"
    done


    rm "$fichier_temp"
    rm "$fichier_time"
} # le programme marche mais très peu rapide...


function ip_rejected_notblocked() {

    fichier_invalid=$(mktemp)  
    ip_inv=$(mktemp)
    grep -i 'invalid' "$fichier_log" > "$fichier_invalid"

    awk '{for (i=4; i<=NF-3; i++) {gsub(/"/, "", $i); if ($i ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/32)?/) print $i}}' "$fichier_invalid" | sort | uniq > "$ip_inv"

    fichier_block=$(mktemp)
    ip_block=$(mktemp)

    grep -iw 'Blocking' "$fichier_log" > "$fichier_block"

    awk '{for (i=1; i<=NF; i++) {gsub(/"/, "", $i); if ($i ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/32)?/) print $i } }' "$fichier_block" | sort | uniq > "$ip_block" 
    
    echo "Adresses IP des utilisateurs bloqués présents dans fichier_invalid :"
    ip_count=$(grep -Ff "$ip_inv" "$ip_block" | sort | uniq)
    echo "$ip_count"

    echo "Nombre d'adresses IP des utilisateurs bloqués présents dans fichier_invalid :"
    echo "$ip_count" | wc -l

    rm "$fichier_invalid"
    rm "$fichier_block"
    rm "$ip_inv"
    rm "$ip_block"
}

function avg_blocked() {
# on somme le temps de blocage puis on divise par le nombre d'occurences
    
    fichier_temp=$(mktemp)
    grep -iw 'Blocking' "$fichier_log" > "$fichier_temp"
    
    head "$fichier_temp"

    temps_total=0
    nb_occurrences=0

    while read -r line; do
        temps=$(echo "$line" | awk '{print $9}')  
        temps_total=$((temps_total + temps))     
        nb_occurrences=$((nb_occurrences + 1))    
    done < "$fichier_temp"

    if [ "$nb_occurrences" -gt 0 ]; then #si nb_occ > 0
        moyenne=$((temps_total / nb_occurrences)) 
        echo "Temps moyen de blocage : $moyenne secs"
    else
        echo "Aucune occurrence de blocage trouvée."
    fi

    rm "$fichier_temp"
} #temps de calcul très long, je ne comprends pas pourquoi
# on a : Temps moyen de blocage : 1729 secs


function dates_attack() { # chaque ligne de block affiche le nombre d'attaques à la suite sans blocage par une même adresse IP et il y a combien de temps la première d'entre elle a été faite. Cela correspond donc à ce qui nous intéresse, on soustrait le temps de la ligne block avec le nombre de seconde affiché dans la ligne log
    echo "rentre une adresse ip:"
    read adresse_ip

    fichier_block=$(mktemp) 
    grep -iw "Blocking \"$adresse_ip/32\"" "$fichier_log" > "$fichier_block"

    while read -r line; do
###### YA DES ERREURS A CORRIGER !!!!!!!
        if echo "$line" | awk '{print $7}' | grep -q "^\"$adresse_ip/32\"$"; then
            date_heure=$(echo "$line" | awk '{print $1,$2,$3}')
            temps=$(echo "$line" | awk '{print $14}')
        
        # Conversion de l'heure en un timestamp UNIX

            timestamp=$(date -d "$date_heure" +"%s")

        # Ajout du temps en secondes
            timestamp_final=$(( timestamp + temps ))

            date_convertie=$(date -d "@$timestamp_final" +"%b %e %H:%M:%S")
            echo "La date de début de l'attaque émanant de l'adresse ip $adresse_ip est $date_heure et celle de fin $date_convertie"
        fi
    done < "$fichier_block"


    rm "$fichier_block"
}





function freq_connexion_valide { # à terminer

    fichier_temp=$(mktemp)
    fichier_disc=$(mktemp)
    
    grep -v -i 'invalid' "$fichier_log" > "$fichier_temp"
    grep -i 'Received disconnect from' "$fichier_temp" > "$fichier_disc"


   # while read -r line; do
   #     date=$(echo "$line" | awk '{print $1, $2}')  
    head "$fichier_disc"

    awk '/Received disconnect from/ {for (i=1; i<=NF; i++) {if ($i == "from" && ($(i+1) ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/32)?/)) print $(i+1)}}' "$fichier_temp" | sort | uniq

    rm "$fichier_temp"
    rm "$fichier_disc"
    
}







# Appel de la fonction spécifiée par l'utilisateur
"$1"
