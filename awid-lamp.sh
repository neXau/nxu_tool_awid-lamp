#!/bin/bash

# Ask the user for the project directory name
read -p "Enter the project directory name: " project_name

# Create the project directory
mkdir "$project_name"
cd "$project_name"

# ==================================================================
# Step 1: Clone the repository and set up the environment
# ==================================================================

git clone https://github.com/sprintcube/docker-compose-lamp.git ./
cp sample.env .env

env_file=".env"

if [ -f "$env_file" ]; then
    # Exporting variables from the .env file
    export $(grep -v '^#' "$env_file" | xargs -d '\n')
else
    echo "Error: File $env_file not found."
    exit 1
fi

# ==================================================================
# Step 2: Open a new terminal window and execute docker-compose up
# ==================================================================

gnome-terminal -- bash -c "sudo docker-compose up; exec bash"

# Wait for the containers to be fully up and running
echo "Waiting for Docker containers to start..."
while ! nc -z localhost $HOST_MACHINE_UNSECURE_HOST_PORT; do
    sleep 30
done
# Containers are up and running
echo "Docker containers are now up and running!"

# ==================================================================
# Step 3: Install WP-CLI
# ==================================================================

sudo docker exec -it $COMPOSE_PROJECT_NAME-$PHPVERSION bash -c "
rm -rf *
curl -L https://raw.github.com/wp-cli/builds/gh-pages/phar/wp-cli.phar > wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/bin/wp
wp --allow-root --version
cd /var/ && chown -R root:www-data www && chmod -R 777 www
exit
"

# ==================================================================
# Step 4: Download and configure WordPress
# ==================================================================

sudo docker exec -it --user www-data $COMPOSE_PROJECT_NAME-$PHPVERSION bash -c "
wget http://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz && rm latest.tar.gz
mv ./wordpress/* ./ && rm -rf ./wordpress/
wp config create --dbhost=database --dbname=$MYSQL_DATABASE --dbuser=$MYSQL_DATABASE --dbpass=$MYSQL_PASSWORD
wp core install --url=localhost --title=$project_name --admin_user=admin --admin_password=admin --admin_email=no@mail.no
touch .htaccess
exit
"
# Clean up
sudo docker exec -it lamp-php8 bash -c "cd /var/ && chown -R root:www-data www && chmod -R 777 www"

echo "WordPress setup is complete!"
xdg-open http:/localhost/

sleep 5
