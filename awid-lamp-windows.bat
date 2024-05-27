@echo off
setlocal

REM Check if Docker is installed
where docker >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Error: Docker is not installed. Please install Docker to continue.
    echo Instructions to install Docker: https://docs.docker.com/get-docker/
    exit /b 1
)

REM Check if Docker Compose is installed
where docker-compose >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Error: Docker Compose is not installed. Please install Docker Compose to continue.
    echo Instructions to install Docker Compose: https://docs.docker.com/compose/install/
    exit /b 1
)

REM Ask the user for the project directory name
set /p project_name=Enter the project directory name: 

REM Create the project directory
mkdir "%project_name%"
cd "%project_name%"

REM ==================================================================
REM Step 1: Clone the repository and set up the environment
REM ==================================================================

git clone https://github.com/sprintcube/docker-compose-lamp.git ./
copy sample.env .env

set "env_file=.env"

if exist "%env_file%" (
    for /f "tokens=1,2 delims==" %%i in ('findstr /v "^#" "%env_file%"') do set "%%i=%%j"
) else (
    echo Error: File %env_file% not found.
    exit /b 1
)

REM ==================================================================
REM Step 2: Open a new terminal window and execute docker-compose up
REM ==================================================================

start "" cmd /c "docker-compose up & echo Docker containers are now up and running! > containers_ready.txt"

REM Wait for the containers to be fully up and running
echo Waiting for Docker containers to start...
:waitloop
if not exist "containers_ready.txt" (
    timeout /t 5 >nul
    goto waitloop
)

REM ==================================================================
REM Step 3: Install WP-CLI
REM ==================================================================

docker exec -it %COMPOSE_PROJECT_NAME%-%PHPVERSION% bash -c "
rm -rf *
curl -L https://raw.github.com/wp-cli/builds/gh-pages/phar/wp-cli.phar > wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/bin/wp
cd /var/ && chown -R root:www-data www && chmod -R 777 www
exit
"

REM ==================================================================
REM Step 4: Download and configure WordPress
REM ==================================================================

docker exec -it --user www-data %COMPOSE_PROJECT_NAME%-%PHPVERSION% bash -c "
wget http://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz && rm latest.tar.gz
mv ./wordpress/* ./ && rm -rf ./wordpress/
wp config create --dbhost=database --dbname=%MYSQL_DATABASE% --dbuser=%MYSQL_DATABASE% --dbpass=%MYSQL_PASSWORD%
wp core install --url=localhost --title=%project_name% --admin_user=admin --admin_password=admin --admin_email=no@mail.no
touch .htaccess
exit
"

REM Clean up
docker exec -it %COMPOSE_PROJECT_NAME%%PHPVERSION% bash -c "cd /var/ && chown -R root:www-data www && chmod -R 777 www"

echo WordPress setup is complete!
start http://localhost:%HOST_MACHINE_UNSECURE_HOST_PORT%

timeout /t 5 >nul
endlocal
