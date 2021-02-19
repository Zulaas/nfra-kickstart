#!/usr/bin/env bash
PROGPATH="$( cd "$(dirname "$0")" ; pwd -P )"   # The absolute path to kickstart.sh
PROJECT_PATH="$PWD"
#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#     DO NOT EDIT THIS FILE!                        CHANGES WILL BE OVERWRITTEN ON UPDATE
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# Ready to use development containers. Just run ./kickstart.sh to start a development
# environment for this project.
#
# Config-File: .kick.yml
# Website..: https://nfra.infracamp.org/
# Copyright: Matthias Leuffen <m@tth.es>
# Released under GNU General Public License <http://www.gnu.org/licenses/gpl-3.0.html>
#
################################################################################################
### DON'T CHANGE ANY VARIABLES HERE --- see ~/.kickstartconfig or ./.kickstartconfig instead ###
################################################################################################

##
KICKSTART_DOCKER_OPTS=""

# Optinal parameters for docker run (e.g. -v /some/host/path:/path)
KICKSTART_DOCKER_RUN_OPTS=""

# External Port bindings
KICKSTART_PORTS="80:80/tcp;4000:4000/tcp;4100:4100/tcp;4200:4200/tcp;4000:4000/udp"

# 1 = Don't try to download the images fr/home/matthes/Projects/infracampom the internet
OFFLINE_MODE=0

# Specify the container name by yourself (switch of auto-detection)
CONTAINER_NAME=

# The image (e.g. infracamp/kickstart-flavor-base:testing) specified in .kick.yml from:-section
FROM_IMAGE=

# The Host IP Address. Leave empty to autodetect.
KICKSTART_HOST_IP=

# Where to mount the current project folder (default: /opt)
DOCKER_MOUNT_PARAMS="-v $PROJECT_PATH/:/opt/"

# User to run inside the container (Default: 'user')
KICKSTART_USER="user"


# For WINDOWS (WSL) users only: Change this for mapping from wsl to docker4win. Execute this in linux shell:
# `echo "KICKSTART_WIN_PATH=C:/" >> ~/.kickstartconfig`
KICKSTART_WIN_PATH=""

# For the skeleton project
KICKSTART_SKEL_INDEX_URL="https://raw.githubusercontent.com/infracamp/nfra-skel/master/skel.index.txt"
KICKSTART_SKEL_DOWNLOAD_URL="https://codeload.github.com/infracamp/nfra-skel/tar.gz/master"


############################
### CODE BELOW           ###
############################

# Error Handling.

set -o errtrace
trap 'on_error $LINENO' ERR;
PROGNAME=$(basename $0)


if test -t 1; then
    # see if it supports colors...
    ncolors=$(tput colors)
    if test -n "$ncolors" && test $ncolors -ge 8; then
        export COLOR_NC='\e[0m' # No Color
        export COLOR_WHITE='\e[1;37m'
        export COLOR_BLACK='\e[0;30m'
        export COLOR_BLUE='\e[0;34m'
        export COLOR_LIGHT_BLUE='\e[1;34m'
        export COLOR_GREEN='\e[0;32m'
        export COLOR_LIGHT_GREEN='\e[1;32m'
        export COLOR_CYAN='\e[0;36m'
        export COLOR_LIGHT_CYAN='\e[1;36m'
        export COLOR_RED='\e[0;31m'
        export COLOR_LIGHT_RED='\e[1;31m'
        export COLOR_PURPLE='\e[0;35m'
        export COLOR_LIGHT_PURPLE='\e[1;35m'
        export COLOR_BROWN='\e[0;33m'
        export COLOR_YELLOW='\e[1;33m'
        export COLOR_GRAY='\e[0;30m'
        export COLOR_LIGHT_GRAY='\e[0;37m'
    fi;
fi;



function on_error () {
    local exit_code=$?
    local prog=$BASH_COMMAND

    echo -e "\e[1;101;30m\n" 1>&2
    echo -en "KICKSTART ERROR: '$prog' (Exit code: $exit_code on ${PROGNAME} line $1) - inspect output above for more information.\n" 1>&2
    echo -e "\e[0m" 1>&2

    exit 1
}


if [[ "$KICKSTART_HOST_IP" == "" ]]
then
    # Autodetect for ubuntu, arch
    KICKSTART_HOST_IP=$(ip route list | grep -v default | grep -v linkdown | grep src | tail -1 | awk 'match($0, / [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/){print substr($0, RSTART+1, RLENGTH-1)}' 2> /dev/null)
fi;
if [[ "$KICKSTART_HOST_IP" == "" ]]
then
    # Workaround for systems not supporting hostname -i (MAC)
    # See doc/workaround-plattforms.md for more about this
    KICKSTART_HOST_IP=$(ping -c 1 $(hostname) | grep icmp_seq | awk 'match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/){print substr($0, RSTART, RLENGTH)}')
fi;


if [[ "$CONTAINER_NAME" == "" ]]
then
    CONTAINER_NAME=${PWD##*/}
fi;



KICKSTART_CACHE_DIR="$HOME/.kick_cache"
mkdir -p $KICKSTART_CACHE_DIR


if [ "$DEV_CONTAINER_NAME" != "" ]
then
    echo -e $COLOR_RED "\n[ERR] Are you trying to run kickstart.sh from inside a kickstart container?!"
    echo "(Detected DEV_CONTAINER_NAME is set in environment)"
    echo -e $COLOR_NC
    exit 4;
fi;

command -v curl >/dev/null 2>&1 || { echo -e "$COLOR_LIGHT_RED I require curl but it's not installed (run: 'apt-get install curl').  Aborting.$COLOR_NC" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo -e "$COLOR_LIGHT_RED I require docker but it's not installed (see http://docker.io).  Aborting.$COLOR_NC" >&2; exit 1; }





_KICKSTART_DOC_URL="https://github.com/nfra-project/nfra-kickstart/"
_KICKSTART_UPGRADE_URL="https://raw.githubusercontent.com/nfra-project/nfra-kickstart/master/dist/kickstart.sh"
_KICKSTART_RELEASE_NOTES_URL="https://raw.githubusercontent.com/nfra-project/nfra-kickstart/master/dist/kickstart-release-notes.txt"
_KICKSTART_VERSION_URL="https://raw.githubusercontent.com/nfra-project/nfra-kickstart/master/dist/kickstart-release.txt"

_KICKSTART_CURRENT_VERSION="1.2.0"

##
# This variables can be overwritten by ~/.kickstartconfig
#



ask_user() {
    echo "";
    read -r -p "$1 (y|N)" choice
    case "$choice" in
      n|N)
        echo "Abort!";
        ;;
      y|Y)
        return 0;
        ;;

      *)
        echo 'Response not valid';;
    esac
    exit 1;
}


if [ ! -f "$PROJECT_PATH/.kick.yml" ]
then
    echo -e $COLOR_RED "[ERR] Missing $PROJECT_PATH/.kick.yml file." $COLOR_NC
    ask_user "Do you want to create a new .kick.yml-file?"
    echo "# Kickstart container config file - see https://gitub.com/infracamp/kickstart" > $PROJECT_PATH/.kick.yml
    echo "# Run ./kickstart.sh to start a development-container for this project" >> $PROJECT_PATH/.kick.yml

    echo "version: 1" >> $PROJECT_PATH/.kick.yml
    echo 'from: "nfra/kickstart-flavor-base"' >> $PROJECT_PATH/.kick.yml
    echo "command:"     >> $PROJECT_PATH/.kick.yml
    echo "  build:"     >> $PROJECT_PATH/.kick.yml
    echo "    - \"echo 'I am executed on build time'\""    >> $PROJECT_PATH/.kick.yml
    echo "  init:"      >> $PROJECT_PATH/.kick.yml
    echo "  test:"      >> $PROJECT_PATH/.kick.yml
    echo "  run:"       >> $PROJECT_PATH/.kick.yml
    echo "  dev:"       >> $PROJECT_PATH/.kick.yml
    echo "    - \"echo 'I am executed in dev mode'\""    >> $PROJECT_PATH/.kick.yml

    echo "File created. See $_KICKSTART_DOC_URL for more information";
    echo ""
    echo "You can now run ./kickstart.sh to start the container"
    sleep 2
    exit 6
fi



# Parse .kick.yml for line from: "docker/container:version"
FROM_IMAGE=`cat $PROJECT_PATH/.kick.yml | grep "^from:" | tr -d '"' | awk '{print $2}'`
if [ "$FROM_IMAGE" == "" ]
then
    echo -e $COLOR_RED "[ERR] .kick.yml file does not include 'from:' - directive." $COLOR_NC
    exit 2
fi;

if [ -e "$HOME/.kickstartconfig" ]
then
    echo "Loading $HOME/.kickstartconfig"
    . $HOME/.kickstartconfig
fi

if [ -e "$PROJECT_PATH/.kickstartconfig" ]
then
    echo "Loading $PROJECT_PATH/.kickstartconfig (This is risky if you - abort if unsure)"
    # @todo Search for .kickstartconfig in gitignore to verify the user wants this.
    . $PROJECT_PATH/.kickstartconfig
fi

terminal="-it"
if [ ! -t 1 ]
then
    # Switch to non-interactive terminal (ci-build etc)
    terminal="-t"
fi;

_usage() {
    echo -e $COLOR_NC "Usage: $0 [<arguments>] [<command>]

    COMMANDS:

        $0 :[command] [command2...]
            Execute kick <command> and return (development mode)

        $0 ci-build
            Build the service and push to gitlab registry (gitlab_ci_runner)

        $0 skel list|install [name]
            List / Install a skeleton project (see http://github.com/infracamp/kickstart-skel)

        $0 skel upgrade
            Upgrade to the latest kickstart version

        $0 secrets list
            List all secrets stored for this project

        $0 secrets edit [secret_name]
            Edit / create secret

        $0 wakeup
            Try to start a previous image with same container name (faster startup)

    EXAMPLES

        $0              Just start a shell inside the container (default development usage)
        $0 :test        Execute commands defined in section 'test' of .kick.yml
        $0 :debug       Execute the container in debug-mode (don't execute kick-commands)

    ARGUMENTS
        -h                    Show this help
        -t, --tag=<tagname>   Run container with this tag (development)
        -u, --unflavored      Run the container whithout running any scripts (develpment)
            --offline         Do not pull images nor ask for version upgrades
            --no-tty          Disable interactive tty
        -e, --env ENV=value   Set environment variables
        -v, --volume  list    Bind mount a volume
        -f, --force           Restart / kill running containers
        -r, --reset           Shutdown all services and restart stack services
            --update-version  Update values in VERSION file (done automatically in ci-build)
            --create-version  Create a mock VERSION file with fixed values (can be committed to repo)
    "
    exit 1
}


_print_header() {
    echo -e $COLOR_WHITE "

 infracamp's
   ▄█   ▄█▄  ▄█   ▄████████    ▄█   ▄█▄    ▄████████     ███        ▄████████    ▄████████     ███
  ███ ▄███▀ ███  ███    ███   ███ ▄███▀   ███    ███ ▀█████████▄   ███    ███   ███    ███ ▀█████████▄
  ███▐██▀   ███▌ ███    █▀    ███▐██▀     ███    █▀     ▀███▀▀██   ███    ███   ███    ███    ▀███▀▀██
 ▄█████▀    ███▌ ███         ▄█████▀      ███            ███   ▀   ███    ███  ▄███▄▄▄▄██▀     ███   ▀
▀▀█████▄    ███▌ ███        ▀▀█████▄    ▀███████████     ███     ▀███████████ ▀▀███▀▀▀▀▀       ███
  ███▐██▄   ███  ███    █▄    ███▐██▄            ███     ███       ███    ███ ▀███████████     ███
  ███ ▀███▄ ███  ███    ███   ███ ▀███▄    ▄█    ███     ███       ███    ███   ███    ███     ███
  ███   ▀█▀ █▀   ████████▀    ███   ▀█▀  ▄████████▀     ▄████▀     ███    █▀    ███    ███    ▄████▀
  ▀                           ▀                                                 ███    ███
  http://infracamp.org                                                                 happy containers
  " $COLOR_YELLOW "
+-------------------------------------------------------------------------------------------------------+
| Infracamp's Kickstart - DEVELOPER MODE                                                                |
| Version: $_KICKSTART_CURRENT_VERSION
| Flavour: $FROM_IMAGE (defined in 'from:'-section of .kick.yml)"



    KICKSTART_NEWEST_VERSION=`curl -s "$_KICKSTART_VERSION_URL"` || true
    if [ "$KICKSTART_NEWEST_VERSION" != "$_KICKSTART_CURRENT_VERSION" ]
    then
        echo "|                                                           "
        echo "| UPDATE AVAILABLE: Head Version: $KICKSTART_NEWEST_VERSION"
        echo "| To Upgrade Version: Run ./kickstart.sh --upgrade                              "
        echo "|                                                                                 "
        sleep 5
    fi;

    echo "| More information: https://github.com/infracamp/kickstart                         "
    echo "| Or ./kickstart.sh help                                                                                |"
    echo "+-------------------------------------------------------------------------------------------------------+"

}


run_shell() {
   echo -e $COLOR_CYAN;
   if [ `docker ps | grep "$CONTAINER_NAME\$" | wc -l` -gt 0 ]
   then
        echo "[kickstart.sh] Container '$CONTAINER_NAME' already running"

        choice="s"

        if [ "$forceKillContainer" -eq "1" ]
        then
            choice="r"
        else
            if [[ "$ARGUMENT" == "" ]]
            then
                read -r -p "Your choice: (S)hell, (r)estart, (a)bort?" choice
            fi
        fi;

        case "$choice" in
            a)
                echo "Abort";
                exit 0;
                ;;

            r|R)
                echo "Restarting container..."
                docker kill $CONTAINER_NAME
                run_container
                exit 0;
                ;;
           s|S|*)
                echo "Starting shell... (please press enter)"
                echo "";

                shellarg="/bin/bash"
                if [ "$ARGUMENT" != "" ]
                then
                    shellarg="kick $ARGUMENT"
                fi;
                echo -e $COLOR_NC;
                docker exec $terminal --user $KICKSTART_USER -e "DEV_TTYID=[SUB]" $CONTAINER_NAME $shellarg

                echo -e $COLOR_CYAN;
                echo "<=== [kickstart.sh] Leaving container."
                echo -e $COLOR_NC
                exit 0;
                ;;
        esac


   fi

   echo "[kickstart.s] Another container is already running!"
   docker ps
   echo ""
   choice="k"
   if [ "$forceKillContainer" -eq "0" ]
   then
      read -r -p "Your choice: (i)gnore/run anyway, (d)isable port-exposure and run, (s)hell, (k)ill, (a)bort?: " choice
   fi;
   case "$choice" in
      i|I)
        run_container
        return 0;
        ;;
      d|D)
        echo "Removing port-exposure... (The container will not have any ports exposed!)"
        KICKSTART_PORTS="";
        ;;
      s|S)
        echo "===> [kickstart.sh] Opening new shell: "
        echo -e $COLOR_NC
        docker exec $terminal --user $KICKSTART_USER -e "DEV_TTYID=[SUB]" `docker ps | grep "/kickstart/" | cut -d" " -f1` /bin/bash

        echo -e $COLOR_CYAN;
        echo "<=== [kickstart.sh] Leaving container."
        echo -e $COLOR_NC
        exit
        ;;
      k|K)
        echo "Killing running kickstart containers..."
        docker kill `docker ps | grep "/kickstart/" | cut -d " " -f1`
        return 0;
        ;;

      *)
        echo 'Response not valid'
        exit 3;
        ;;

    esac
}

versionFile="${PROJECT_PATH}/VERSION"

_write_version_file_real() {
    [ -f $versionFile ] || return; # Skip if VERSION is not present

    echo "Updating Version file $versionFile";

    echo "# This is an autogenerated Version file (from kickstart): See nfra.infracamp.org for details" > $versionFile
    echo $(git log --oneline | wc -l) >> $versionFile             # Version History Number
    echo $(date -R) >> $versionFile                               # Build Date
    echo $(git log -1 --pretty=format:'%aD') >> $versionFile      # Author Date
    echo $(git log -1 --pretty=format:'%h') >> $versionFile       # Commit ID
    echo $(git log -1 --pretty=format:'%aN') >> $versionFile      # Author
    echo $CI_BUILD_TAG >> $versionFile                            # Tag Name
}

_write_version_file_dev() {
    # To prevent merge issues, kickstart will keep the version file fixed
    # with default values during development. Only ci_build will write the
    # real values
    echo "Writing fixed development Version file $versionFile";

    echo "# This is an autogenerated Version file (by kickstart): See nfra.infracamp.org for details" > $versionFile
    echo "0" >> $versionFile             # Version History Number
    echo "Fri, 19 Feb 2021 12:33:13 +0100" >> $versionFile                               # Build Date
    echo "Fri, 19 Feb 2021 12:33:13 +0100" >> $versionFile      # Author Date
    echo "devdev" >> $versionFile       # Commit ID
    echo "developer name" >> $versionFile       # Author
    echo "0.0" >> $versionFile
}


_ci_build() {
    _write_version_file_real;
    echo "CI_BUILD: Building container.. (CI_* Env is preset by gitlab-ci-runner)";
    [[ "$CI_REGISTRY" == "" ]] && echo "[Error deploy]: Environment CI_REGISTRY not set" && exit 1;
    [[ "$CI_BUILD_NAME" == "" ]] && echo "CI_BUILD_NAME not set - setting default tag to 'latest'" && CI_BUILD_NAME="latest";

    local imageName="$CI_REGISTRY_IMAGE:$CI_BUILD_NAME"

    CMD="docker build --pull -t $imageName -f ./Dockerfile ."
    echo "[Building] Running '$CMD' (MODE1)";
    eval $CMD

    if [ "$CI_REGISTRY_PASSWORD" != "" ]
    then
        echo "Logging in to: $CI_REGISTRY_USER @ $CI_REGISTRY"
        echo "$CI_REGISTRY_PASSWORD" | docker login --username $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
    else
        echo "No registry credentials provided in env CI_REGISTRY_PASSWORD - skipping docker login."
    fi;

    docker push $imageName
    echo "Push successful (Image: $imageName)..."

    if [ "$CI_BUILD_TAG" != "" ]
    then
        ## For Gitlab CI
        local taggedImageName="$CI_REGISTRY_IMAGE:$CI_BUILD_TAG"
        echo  "CI_BUILD_TAG found: '$CI_BUILD_TAG' - pushing to '$taggedImageName'"
        docker tag $imageName $taggedImageName
        docker push $taggedImageName
        echo "Push successful (Image: $taggedImageName)..."
    fi;

    exit
}



DOCKER_OPT_PARAMS=$KICKSTART_DOCKER_RUN_OPTS;


# Load .env before evaluating -e command line options
if [ -e "$PROJECT_PATH/.env" ]; then
    echo "Adding docker environment from $PROJECT_PATH/.env (Development only)"
    DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS --env-file $PROJECT_PATH/.env";
elif [ -e "$PROJECT_PATH/.env.dist" ] && [ "$#" == "0" ]; then
    echo "An '.env' file is not existing but a '.env.dist' was found."
    echo ""
    echo "This normally indicates that you have to create a developers .env manually"
    echo "in order to start the project."
    echo ""
    read -r -p "Hit (enter) to continue without .env file or CTRL-C to exit." choice
fi





run_container() {
    echo -e $COLOR_GREEN"Loading container '$FROM_IMAGE'..."
    if [ "$OFFLINE_MODE" == "0" ]
    then
        docker pull "$FROM_IMAGE"
    else
        echo -e $COLOR_RED "OFFLINE MODE! Not pulling image from registy. " $COLOR_NC
    fi;

    # Ports to be exposed
    IFS=';' read -r -a _ports <<< "$KICKSTART_PORTS"
    for _port in "${_ports[@]}"
    do
        DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS -p $_port"
    done

    ## Mutliarch support
    ##imageArchitecture=$( docker image inspect "$FROM_IMAGE" -f '{{.Architecture}}')
    isArmImage=$(echo "$FROM_IMAGE" | grep "arm32v7") || true
    isX86=$(uname -m | grep "x86") || true

    if [ "$isX86" != "" ] && [ "$isArmImage" != '' ]
    then
        ask_user "You are trying to load arm32 image on x86 architecture. Enable multiarch/qemu?"
        docker run --rm --privileged multiarch/qemu-user-static:register --reset --credential yes
    fi

	if [ "$KICKSTART_WIN_PATH" != "" ]
	then
		# For Windows users: Rewrite Path of bash to Windows path
		# Will work only on drive C:/
		PROGPATH="${PROGPATH/\/mnt\/c\//$KICKSTART_WIN_PATH}"
		DOCKER_MOUNT_PARAMS="-v $PROJECT_PATH/:/opt/"
	fi

    docker rm $CONTAINER_NAME || true
    echo -e $COLOR_WHITE "==> [$0] STARTING CONTAINER (docker run): Running container in dev-mode..." $COLOR_NC


    _STACKFILE="$PROJECT_PATH/.kick-stack.yml"
    if [ -e "$_STACKFILE" ]; then
        _STACK_NETWORK_NAME=$CONTAINER_NAME

        if [ $resetServices -eq 1 ]
        then
          echo "Reset Services. Leaving swarm..."
          docker swarm leave --force
        fi;

        echo "Startin in stack mode... (network: '$_STACK_NETWORK_NAME')"
        _NETWORKS=$(docker network ls | grep $_STACK_NETWORK_NAME | wc -l)
        echo nets: $_NETWORKS
        if [ $_NETWORKS -eq 0 ]; then
            docker swarm init --advertise-addr $KICKSTART_HOST_IP || true
            docker network create --attachable -d overlay $_STACK_NETWORK_NAME
        fi;

        docker stack deploy --prune --with-registry-auth -c $_STACKFILE $CONTAINER_NAME
        DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS --network $_STACK_NETWORK_NAME"
    fi;


    dev_uid=$UID
    if [ ! -t 1 ]
    then
        # Switch to non-interactive terminal (ci-build etc)
        # For Gitlab Actions: $UID unset (use uid of path)
        dev_uid=$(stat -c '%u' $PROJECT_PATH)
    fi;

    if [ "$dev_uid" -eq "0" ]
    then
        # Never run a container as root user
        # For Gitlab-CI: Gitlab-CI checks out everything world writable but as user root (0) => Set UID to normal user
        # (otherwise composer / npm won't install)
        dev_uid=1000
    fi;

    cmd="docker $KICKSTART_DOCKER_OPTS run $terminal                \
            $DOCKER_MOUNT_PARAMS                           \
            -e \"DEV_CONTAINER_NAME=$CONTAINER_NAME\"         \
            -e \"DEV_TTYID=[MAIN]\"                           \
            -e \"DEV_UID=$dev_uid\"                               \
            -e \"DOCKER_HOST_IP=$KICKSTART_HOST_IP\"               \
            -e \"TERM=$TERM\"                                 \
            -e \"DEV_MODE=1\"                                 \
            $DOCKER_OPT_PARAMS                              \
            --name $CONTAINER_NAME                          \
            $FROM_IMAGE $ARGUMENT"
    echo [exec] $cmd
    eval $cmd

    status=$?
    if [[ $status -ne 0 ]]
    then
        echo -e $COLOR_RED
        echo "[kickstart.sh][FAIL]: Container startup failed."
        echo -e $COLOR_NC
        exit $status
    fi;
    echo -e $COLOR_WHITE "<== [kickstart.sh] CONTAINER SHUTDOWN"
    echo -e $COLOR_RED "    Kickstart Exit - Goodbye" $COLOR_NC
    exit 0;
}



forceKillContainer=0
ARGUMENT="";
# Parse the command parameters
ARGUMENT="";
resetServices=0;
while [ "$#" -gt 0 ]; do
  case "$1" in
    -t) USE_PIPF_VERSION="-t $2"; shift 2;;
    --tag=*)
        USE_PIPF_VERSION="-t ${1#*=}"; shift 1;;

    -e|--env) DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS -e '$2'"; shift 2;;

    -v|--volume) DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS -v '$2'"; shift 2;;

    -f|--force)
        forceKillContainer=1;
        shift 1;
        ;;

    -r|--reset)
        resetServices=1;
        shift 1;
        ;;

    --update-version)
        _write_version_file_dev
        _write_version_file_real
        shift 1;
        ;;
    --create-version)
        _write_version_file_dev
        shift 1;
        ;;

    --offline)
        OFFLINE_MODE=1; shift 1;;

    --no-tty)
        echo "Disabling interactive terminal"
        terminal=""
        shift 1;;

    upgrade|--upgrade)
        echo "Checking for updates from $_KICKSTART_UPGRADE_URL..."
        curl "$_KICKSTART_RELEASE_NOTES_URL"

        ask_user "Do you want to upgrade?"

        echo "Writing to $0..."
        curl "$_KICKSTART_UPGRADE_URL" -o "$0"
        echo "Done"
        echo "Calling on update trigger: $0 --on-after-update"
        $0 --on-after-upgrade
        echo -e "$COLOR_GREEN[kickstart.sh] Upgrade successful.$COLOR_NC"
        exit 0;;

    --on-after-upgrade)
        exit 0;;

    wakeup)
        docker start -ai $CONTAINER_NAME
        exit 0;;

    skel)
        if [ "$2" == "install" ]
        then
            ask_user "Do you want to overwrite existing files with skeleton?"
            curl $KICKSTART_SKEL_DOWNLOAD_URL | tar -xzv --strip-components=2 kickstart-skel-master/$3/ -C ./
            exit 0;
        fi;

        if [ "$2" == "" ] || [ "$2" == "list" ]
        then
            echo "------ List of available skeleton projects -------"
            curl $KICKSTART_SKEL_INDEX_URL
            echo ""
            echo "--------------------------------------------------"
            echo "Install a skeleton: $0 skel install <name>"
            echo "";
        else
            echo "Unknown command: Available: $0 --skel list|install <name>"
            exit 1
        fi
        exit 0;;

    secrets)
        secretDir="$HOME/.kickstart/secrets/$CONTAINER_NAME"
        mkdir -p $secretDir

        [[ "$2" == "list" ]] && echo "Listing secrets from $secretDir:" && ls $secretDir && exit 0;

        [[ "$2" != "edit" ]] && echo -e "Error: No secret specified\nUsage: $0 secrets list|edit [<secretname>]" && exit 1;

        [[ "$3" == "" ]] && echo -e "Error: No secret specified\nUsage: $0 secrets list|edit [<secretname>]" && exit 1;

        secretFile=$secretDir/$3

        editor $secretFile
        echo "Edit successful: $secretFile"

        exit 0;;


    ci-build|--ci-build)
        _ci_build $2 $3
        exit0;;

    help|-h|--help)
        _usage
        exit 0;;

    --tag) echo "$1 requires an argument" >&2; exit 1;;

    :*)
        ARGUMENT="${1:1} ${@:2}"
        break;;

    -*) echo "unknown option: $1" >&2; exit 1;;

    *)
        echo "invalid command: $1 - see $0 help for more information" >&2; exit 2;;
  esac
done

if [ -e "$HOME/.ssh" ]
then
    echo "Mounting $HOME/.ssh..."
    DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS -v $HOME/.ssh:/home/user/.ssh";
fi

if [ -e "$HOME/.gitconfig" ]
then
    echo "Mounting $HOME/.gitconfig..."
    DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS -v $HOME/.gitconfig:/home/user/.gitconfig";
fi

if [ -e "$HOME/.git-credentials" ]
then
    echo "Mounting $HOME/.git-credentials..."
    DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS -v $HOME/.git-credentials:/home/user/.git-credentials";
fi

if [ -e "$HOME/.bash_history" ]
then
    bashHistoryFile="$HOME/.kickstart/bash_history/$CONTAINER_NAME";
    echo "Mounting containers bash-history from $bashHistroyFile..."
    mkdir -p $(dirname $bashHistoryFile)
    touch $bashHistoryFile
    DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS -v $bashHistoryFile:/home/user/.bash_history";
fi



secretsPath="$HOME/.kickstart/secrets/$CONTAINER_NAME"
echo "Scanning for secrets in $secretsPath";
if [ -e $secretsPath ]
then
    for _cur_secret_name in $(find $secretsPath -type f -printf "%f\n")
    do
        echo "Adding secret from $secretsPath/$_cur_secret_name -> /run/secrets/$_cur_secret_name"
        DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS -v '$secretsPath/$_cur_secret_name:/run/secrets/$_cur_secret_name' "
    done;
fi;


echo "Scanning env for KICKSECRET_*";
for secret in $(env | grep ^KICKSECRET | sed 's/KICKSECRET_\([a-zA-Z0-9_]\+\).*/\1/'); do
    secretName="KICKSECRET_$secret"
    secretFile="/tmp/.kicksecret.$secretName"
    echo ${!secretName} > $secretFile
    echo "+ adding secret from env: $secretName > /run/secrets/$secret";
    DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS -v '$secretFile:/run/secrets/$secret' "
done;




DOCKER_OPT_PARAMS="$DOCKER_OPT_PARAMS -v $KICKSTART_CACHE_DIR:/mnt/.kick_cache"



_print_header
if [ `docker ps | grep "/kickstart/" | wc -l` -gt 0 ]
then
    run_shell
fi;
run_container
