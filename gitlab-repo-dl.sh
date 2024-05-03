#!/usr/bin/env bash

if [ "$1" == "all" ]; then
    GITLAB_URL="set me"
    GITLAB_TOKEN="set me"
fi

if [ "$1" == "all-in-one" ]; then
    GITLAB_URL="set me"
    GITLAB_TOKEN="set me"
fi

if [ -z "$GITLAB_URL" ]; then
    echo "Missing environment variable: GITLAB_URL (e.g. https://gitlab.com)"
    exit 1
fi

if [ -z "$GITLAB_TOKEN" ]; then
    echo "Missing environment variable: GITLAB_TOKEN"
    echo "See ${GITLAB_URL}profile/account."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Action is required. Can be one of 'group', 'all-repo-list', 'from-list'"
    exit 1
fi

if [ "$1" == "group" ]; then
    if [ -z "$2" ]; then
        echo "Group name is required."
        exit 1
    fi

    GROUP_NAME="$2"

    echo "Cloning all git projects in group $GROUP_NAME"

    REPO_SSH_URLS=$(curl -s "$GITLAB_URL/api/v4/groups/$GROUP_NAME/projects?include_subgroups=true&private_token=$GITLAB_TOKEN&per_page=999" | jq '.[] | .ssh_url_to_repo' | sed 's/"//g')

    for REPO_SSH_URL in $REPO_SSH_URLS; do
        REPO_PATH="$GROUP_NAME/$(echo "$REPO_SSH_URL" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}{print $2}')"

        if [ ! -d "$REPO_PATH" ]; then
            echo "git clone $REPO_PATH"
            git clone "$REPO_SSH_URL" "$REPO_PATH"
        else
            echo "git pull $REPO_PATH"
            (cd "$REPO_PATH" && git pull)
        fi
    done
elif [ "$1" == "all-repo-list" ]; then
    # Get total number of pages (with 20 projects per page) from HTTP header
    TOTAL_PAGES=$(curl "$GITLAB_URL/api/v4/projects?include_subgroups=true&private_token=$GITLAB_TOKEN" -sI | grep X-Total-Pages | awk '{print $2}' | sed 's/\\r//g')

    for ((PAGE_NUMBER = 1; PAGE_NUMBER <= TOTAL_PAGES; PAGE_NUMBER++)); do
        # echo git@instance:namespace/repo.git
        curl "$GITLAB_URL/api/v4/projects?include_subgroups=true&private_token=$GITLAB_TOKEN&per_page=20&page=$PAGE_NUMBER" | jq '.[] | .ssh_url_to_repo' | sed 's/"//g'
    done
elif [ "$1" == "from-list" ]; then
    if [ -z "$2" ]; then
        echo "List file name required"
        exit 1
    fi

    if [ -z "$3" ]; then
        echo "Target directory required"
        exit 1
    fi

    LIST_FILE="$2"
    TARGET_DIR="$3"

    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$TARGET_DIR"
    fi

    while read REPO_SSH_URL; do
        REPO_PATH="$(echo "$REPO_SSH_URL" | awk -F':' '{print $NF}' | awk -F'.' '{print $1}')"

        if [ ! -d "$TARGET_DIR/$REPO_PATH" ]; then
            echo "git clone $REPO_PATH"
            git clone "$REPO_SSH_URL" "$TARGET_DIR/$REPO_PATH"
        else
            echo "git pull $REPO_PATH"
            (cd "$TARGET_DIR/$REPO_PATH" && git pull)
        fi
    done <"$LIST_FILE"


## downlad everything
elif [ "$1" == "all" ]; then

    GITLAB_URL="$2"
    GITLAB_TOKEN="$3"

    MYGROUPS=$(curl -s "$GITLAB_URL/api/v4/groups/?private_token=$GITLAB_TOKEN&per_page=999" | jq '.[].path' | sed 's/"//g')

    for CURRENT_GROUP in $MYGROUPS; do
        REPO_SSH_URLS=$(curl -s "$GITLAB_URL/api/v4/groups/$CURRENT_GROUP/projects?include_subgroups=true&private_token=$GITLAB_TOKEN&per_page=999" | jq '.[] | .ssh_url_to_repo' | sed 's/"//g')
        
        for u in $REPO_SSH_URLS; do
            
            echo "$u"            
            read -a parts <<< "$u"
            
            REPO_PATH="$(echo "$parts" | awk -F':' '{print $2}' | awk -F'.' '{print $1}' | awk -F'/' '{print $1 "-" $2}' )"
            echo "$REPO_PATH"

            if [ ! -d "$REPO_PATH" ]; then
                echo "git clone $u"
                git clone "$u" "$REPO_PATH"
            else
                echo "git pull $REPO_PATH"
                (cd "$REPO_PATH" && git pull)
            fi
        done
    done

elif [ "$1" == "all-in-one" ]; then

    GITLAB_URL="$2"
    GITLAB_TOKEN="$3"

    MYGROUPS=$(curl -s "$GITLAB_URL/api/v4/groups/?private_token=$GITLAB_TOKEN&per_page=999" | jq '.[].path' | sed 's/"//g')

    for CURRENT_GROUP in $MYGROUPS; do

        if [ ! -d "$CURRENT_GROUP" ]; then
            mkdir "$CURRENT_GROUP"
            cd "$CURRENT_GROUP" || exit
        else
            cd "$CURRENT_GROUP" || exit
        fi

        REPO_SSH_URLS=$(curl -s "$GITLAB_URL/api/v4/groups/$CURRENT_GROUP/projects?include_subgroups=true&private_token=$GITLAB_TOKEN&per_page=999" | jq '.[] | .ssh_url_to_repo' | sed 's/"//g')

        for REPO_SSH_URL in $REPO_SSH_URLS; do
            REPO_PATH="$(echo "$REPO_SSH_URL" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}{print $2}')"

            if [ ! -d "$REPO_PATH" ]; then
                echo "git clone $REPO_PATH"
                git clone "$REPO_SSH_URL" "$REPO_PATH"
            else
                echo "git pull $REPO_PATH"
                (cd "$REPO_PATH" && git pull)
            fi
        done
        cd ..
    done
fi

