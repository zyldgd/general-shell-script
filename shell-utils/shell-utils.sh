#!/bin/bash
WORK_PATH=$(dirname $(readlink -f $0))

JDK_TAR_PATH=""
JAVA_HOME_PATH="/opt/java"

MAVEN_TAR_PATH=" "
MAVEN_HOME_PATH="/opt/maven"

PROFILE_PATH="/etc/profile"

# @static yes
# @param 1: envionment variable
# @param 2: value of the envionment variable
function add_env() {
    echo "add <$1> to <$2>"
    if [[ $(echo $$1) =~ $2 ]]; then
        echo $(echo $$1)
    else
        echo "export $1=$2" >>${PROFILE_PATH}
    fi
    source ${PROFILE_PATH}
}

# @static no
# @request jdk
function install_java() {
    if [-d "${JAVA_HOME_PATH}" ]; then
        rm -rf ${JAVA_HOME_PATH}/*
    else
        mkdir ${JAVA_HOME_PATH}
        echo "[INFO] make dir <${JAVA_HOME_PATH}>"
    fi
    echo "[INFO] tar -xzvf ${JDK_TAR_PATH} -C ${JAVA_HOME_PATH} --strip-components 1"
    su -s /bin/bash -c "tar -xzvf ${JDK_TAR_PATH} -C ${JAVA_HOME_PATH} --strip-components 1" root

    # echo 'ulimit -n 65535' >> /etc/profile

    add_env JAVA_HOME ${JAVA_HOME_PATH}
    add_env JRE_HOME "${JAVA_HOME}/jre"
    add_env CLASSPATH ".:${JAVA_HOME}/lib:${JRE_HOME}/lib"
    add_env KARAF_OPTS '-verbose:gc -XX:+PrintGCTimeStamps -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:data/log/gc.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=3 -XX:GCLogFileSize=100M'
    add_env JAVA_OPTS '-Xms4096m -Xmx32768m -Xmn4096m -XX:+DisableExplicitGC -XX:+CMSParallelRemarkEnabled -XX:MaxGCPauseMillis=100 -XX:ParallelGCThreads=20 -XX:+CMSClassUnloadingEnabled -XX:CMSInitiatingOccupancyFraction=70'
    add_env PATH "${JAVA_HOME}/bin:${PATH}"
}

# @static no
# @request maven
function install_maven() {
    if [-d "${MAVEN_HOME_PATH}" ]; then
        rm -rf ${MAVEN_HOME_PATH}/*
    else
        mkdir ${MAVEN_HOME_PATH}
        echo "[INFO] make dir <${MAVEN_HOME_PATH}>"
    fi
    echo "[INFO] tar -xzvf ${MAVEN_TAR_PATH} -C ${MAVEN_HOME_PATH} --strip-components 1"
    su -s /bin/bash -c "tar -xzvf ${MAVEN_TAR_PATH} -C ${MAVEN_HOME_PATH} --strip-components 1" root

    # echo 'ulimit -n 65535' >> /etc/profile
    add_env M2_HOME ${MAVEN_HOME_PATH}
    add_env CLASSPATH "${CLASSPATH}:${M2_HOME}/lib"
    add_env PATH "${M2_HOME}/bin:${PATH}"

    if [-d "/root/.m2" ]; then
        rm -rf /root/.m2/*
    else
        mkdir /root/.m2
        echo "[INFO] make dir </root/.m2>"
    fi

    cp /install/maven/settings.xml /root/.m2/settings.xml
    echo "[INFO] cp /install/maven/settings.xml /root/.m2/settings.xml"
}

# @static yes
function maven_clean_install() { 
    mvn clean install -DskipTests -Dcheckstyle.skip -Dmaven.javadoc.skip=true -Djacoco.skip
    echo "[INFO] mvn clean install -DskipTests -Dcheckstyle.skip -Dmaven.javadoc.skip=true -Djacoco.skip"
}

# @static yes
# @param 1: username
# @param 2: password
# @param 3: shared path (win)
# @param 4: mounted path (local)
function mount_windows() {
    mount -t cifs -o username='zhaoyulai',password='Zyldgd123.' //10.69.65.119/share/  /mnt/share
    #mount -t cifs -o username="${1}",password="${2}" ${3} ${4}
}


function cp_tar_run() {
    #--------------------------------------------------
    REPOSITORY_PATH="/mnt/share/workplace"
    ENV_PATH='/var/workplace/share/ENV'
    #--------------------------------------------------

    REPOSITORIES=$(ls $REPOSITORY_PATH)
    if [[ $REPOSITORIES == '' ]]; then
        echo "[ERROR] There is no any repository at <$REPOSITORY_PATH>"
        exit 1
    fi

    echo "[INFO] Your environments locate in <$REPOSITORY_PATH>"
    echo "[INFO] Your repositories locate in <$REPOSITORY_PATH>"
    echo "[INFO] Select your repository:"
    select repository in $REPOSITORIES; do
        if [[ $repository != '' && $REPOSITORIES =~ $repository ]]; then
            echo "[INFO] Your have selected <$repository>"
            break
        fi
    done

    PROJECTS_PATH="${REPOSITORY_PATH}/${repository}"

    PROJECTS=$(ls ${PROJECTS_PATH})
    if [[ $PROJECTS == '' ]]; then
        echo "[ERROR] There is no any project at <$PROJECTS_PATH>"
        exit 1
    fi

    echo "[INFO] Select your project:"
    select project in $PROJECTS; do
        if [[ $project != '' && $PROJECTS =~ $project ]]; then
            echo "[INFO] Your have selected <$project>"
            break
        fi
    done

    PROJECT_PATH="${PROJECTS_PATH}/${project}"

    TARGET_PATH="${PROJECT_PATH}/karaf/target"
    TAR_GZ_PATH=$(ls ${TARGET_PATH}/*.tar.gz)
    TAR_GZ_NAME=${TAR_GZ_PATH##*/}

    if [ -f "${TAR_GZ_PATH}" ]; then
        echo "[INFO] Name of the tar is <${TAR_GZ_NAME}>"
        echo "[INFO] <${TAR_GZ_PATH}> will be decompressed later"
    else
        echo "[ERROR] file<${TAR_GZ_PATH}> dosen't exise, please check out it!"
        exit 1
    fi

    if [ ! -d "${ENV_PATH}/${repository}" ]; then
        mkdir "${ENV_PATH}/${repository}"
        echo "[INFO] make dir <${ENV_PATH}/${repository}>"
    fi

    RUN_PATH="${ENV_PATH}/${repository}/${project}"

    if [ ! -d "${RUN_PATH}" ]; then
        mkdir "${RUN_PATH}"
        echo "[INFO] make dir <${RUN_PATH}>"
    else
        rm -rf "${RUN_PATH}"
        echo "[INFO] remove <${RUN_PATH}>"
        mkdir "${RUN_PATH}"
        echo "[INFO] make dir <${RUN_PATH}>"
    fi

    cp $TAR_GZ_PATH "${RUN_PATH}/${TAR_GZ_NAME}"
    echo "[INFO] cp ${RUN_PATH}/${TAR_GZ_NAME}"

    TARGET_NAME=$(basename $TAR_GZ_NAME .tar.gz)

    echo "[INFO] tar -xzvf ${RUN_PATH}/${TAR_GZ_NAME} -C ${RUN_PATH}/"
    su -s /bin/bash -c "mkdir ${RUN_PATH}/${TARGET_NAME}" root
    su -s /bin/bash -c "tar -xzvf ${RUN_PATH}/${TAR_GZ_NAME} -C ${RUN_PATH}/${TARGET_NAME} --strip-components 1" root

    echo "[INFO] ${RUN_PATH}/${TARGET_NAME}/bin/karaf" debug
    "${RUN_PATH}/${TARGET_NAME}/bin/karaf" debug
}

function main() {
    echo "[INFO] Select your function:"
    my_functions="${my_functions} cp_tar_run"
    my_functions="${my_functions} install_java"
    my_functions="${my_functions} install_maven"
    my_functions="${my_functions} maven_clean_install"
    my_functions="${my_functions} mount_windows"

    select fun in ${my_functions}; do
        if [[ $fun != '' && $my_functions =~ $fun ]]; then
            echo "[INFO] Your have selected <$fun>"
            $fun
            break
        fi
    done
    
    unset my_functions
}

main