#!/bin/bash
#Author:ruozhou.chen@rock-chips.com
#Date:20240915
#Function:Generate Credential with Copyright_Statement

#!/bin/bash

CONFIG_FILE=~/rk_test_config
TEMP_CONFIG_FILE=$(mktemp)
REMOTE_HOST="gerrit.rock-chips.com"
HTTP_PORT="8443"
SSH_PORT="8222"

# Set the correct permissions for the config file
touch ~/rk_test_config
touch ~/rk_gerrit_log

# Check if the required configuration for the Gerrit server exists in the config file
if ! grep -q "Host $REMOTE_HOST" $CONFIG_FILE; then
    echo "Adding configuration for Gerrit server to $CONFIG_FILE"
    echo "Host $REMOTE_HOST\n    HostName $REMOTE_HOST\n    PreferredAuthentications publickey\n    StrictHostKeyChecking no\n    UserKnownHostsFile ~/.ssh/known_hosts\n    PubkeyAcceptedKeyTypes +ssh-rsa" >> $TEMP_CONFIG_FILE
    cat $CONFIG_FILE >> $TEMP_CONFIG_FILE
    mv $TEMP_CONFIG_FILE $CONFIG_FILE
fi

# Set the correct permissions for the config file
chmod 644 $CONFIG_FILE

echo "***********************************************************************************************************************************************************************************************************************************************"
echo " Copyright Statement                                                                                                                                                                                                                           "
echo "                                                                                                                                                                                                                                               "
echo " Copyright (C) 2024 Rockchip Electronics Co., Ltd. All rights reserved.                                                                                                                                                                        "
echo "                                                                                                                                                                                                                                               "
echo " BY OPENING OR USING THIS FILE, RECEIVER HEREBY ACKNOWLEDGES AND AGREES THAT THE SOFTWARE/FIRMWARE AND ITS DOCUMENTATIONS (\"ROCKCHIP SOFTWARE\") RECEIVED FROM ROCKCHIP ON AN \"AS-IS\" BASIS ONLY WITHOUT ANY AND ALL WARRANTIES,            "
echo " EITHER EXPRESS, IMPLIED OR STATUTORY, INCLUDING, WITHOUT LIMITATION, ANY WARRANTY OR CONDITION WITH RESPECT TO TITLE, MERCHANTABILITY, FITNESS FOR ANY PARTICULAR PURPOSE, OR NON-INFRINGEMENT.                                               "
echo " NEITHER DOES ROCKCHIP PROVIDE ANY WARRANTY WHATSOEVER WITH RESPECT TO ANY OPEN SOURCE TECHNOLOGIES, THIRD-PARTY TECHNOLOGIES OR ANY STANDARD TECHNOLOGIES WHICH MAY BE SUPPORTED BY, INCORPORATED IN, OR SUPPLIED WITH THE ROCKCHIP SOFTWARE. "
echo " RECEIVER EXPRESSLY ACKNOWLEDGES THAT IT IS RECEIVER'S SOLE RESPONSIBILITY TO OBTAIN AND MAINTAIN ALL NECESSARY LICENSES AND RIGHTS FROM THEIR RESPECTIVE OWNERS TO USE ANY SUCH THIRD-PARTY TECHNOLOGIES OR ANY STANDARD TECHNOLOGIES.        "
echo " RECEIVER'S SOLE AND EXCLUSIVE REMEDY AND ROCKCHIP'S ENTIRE AND CUMULATIVE LIABILITY WITH RESPECT TO THE ROCKCHIP SOFTWARE RELEASED HEREUNDER WILL BE, AT ROCKCHIP 'S OPTION, TO REVISE OR REPLACE THE ROCKCHIP SOFTWARE AT ISSUE,             "
echo " OR REFUND ANY FEES OR CHARGE PAID BY RECEIVER TO ROCKCHIP FOR SUCH ROCKCHIP SOFTWARE AT ISSUE.                                                                                                                                                "
echo "***********************************************************************************************************************************************************************************************************************************************"

echo -n "Do you agree to the above terms? (yes/no) "
read -r answer

if [[ $answer != "yes" ]]; then
  echo "You must agree to the terms to continue."
  exit 1
fi

# Loop to check if the SSH key is working for the given USER_NAME
while true; do
    read -r -p "Please input your username (make sure to use the username exactly the same as the one in RK email!!): " USER_NAME
    read -r -p "Please input your email (make sure to use the company email address!!): " USER_EMAIL
    read -r -p "Please input your SSH private key filename (e.g. id_rsa): " USER_KEY

    # Test the SSH key and write the output to a log file
    ssh -vT -p $SSH_PORT -i ~/.ssh/$USER_KEY -F $CONFIG_FILE $USER_NAME@$REMOTE_HOST > ~/rk_gerrit_log 2>&1

    # Check if the SSH key authentication was successful
    if grep -q "you have successfully connected over SSH" ~/rk_gerrit_log; then
        echo "Your Credential check has passed"

        encodedName=$(echo "$USER_NAME" | sed 's/@/%40/g')

        filelocate=$(find ~/.git-credentials | wc -l)

        if [ "$filelocate" -eq 0 ];then
           echo "You don't have any git credential history!!"
           ssh -p $SSH_PORT -i ~/.ssh/$USER_KEY -F $CONFIG_FILE $USER_NAME@$REMOTE_HOST gerrit set-account --generate-http-password $USER_NAME | cut -d ":" -f 2 | sed 's/+/%2b/g' | sed 's/\//%2f/g' > ~/httppassword
           sleep 1s
           while read -r line
              do
                  httppassword=$(echo "$line")
              done <~/httppassword
           if [ ! "$httppassword" ];then
              echo "Your Credential has failed, Please contact RK system administrator for assistance!!"
           else
              echo "https://$encodedName:$httppassword@gerrit.rock-chips.com%3a8443" > ~/.git-credentials
              git config --global credential.helper store
              echo "You are All Set!!"
           fi
        else
           mv ~/.git-credentials ~/git-credentials
           ssh -p $SSH_PORT -i ~/.ssh/$USER_KEY -F $CONFIG_FILE $USER_NAME@$REMOTE_HOST gerrit set-account --generate-http-password $USER_NAME | cut -d ":" -f 2 | sed 's/+/%2b/g' | sed 's/\//%2f/g' > ~/httppassword
           sleep 1s
           while read -r line
              do
                  httppassword=$(echo "$line")
              done <~/httppassword
           if [ ! "$httppassword" ];then
              echo "Your Credential has failed, Please contact RK system administrator for assistance!!"
           else
              echo "https://$encodedName:$httppassword@gerrit.rock-chips.com%3a8443" > ~/.git-credentials
              sed '/gerrit.rock-chips.com/d' ~/git-credentials >> ~/.git-credentials
              git config --global credential.helper store
              echo "New git credential will be added into your history!!"
              rm ~/git-credentials
              echo "You are All Set!!"
           fi
        fi

        git config --global user.email "$USER_EMAIL"
        git config --global user.name "$USER_NAME"

        rm ~/rk_gerrit_log
        rm ~/rk_test_config

        break  # Exit the loop since authentication was successful

    elif grep -q "Connection refused" ~/rk_gerrit_log; then
        echo "Network connection issue, please contact IT department to confirm that the communication via HTTPS 8443 and SSH 8222 for synchronization hasn't been blocked by security devices."
    elif grep -q "Permission denied" ~/rk_gerrit_log; then
        echo "Credential mismatch issue, please refer to the instruction documents attached to the Rockchip-SDK Ready email to correctly configure the gerrit account and ssh key."
    else
        echo "SSH key authentication failed. Please provide a screenshot of the error or the log file to Rockchip technical support."
    fi

    # Prompt the user to retry or exit
    while true; do
        read -p "Do you want to retry (y/n)? " choice
        case "$choice" in
            y|Y ) break;;  # Break from the inner loop to retry SSH authentication
            n|N ) exit;;   # Exit the script if the user chooses not to retry
            * ) echo "Invalid input. Please enter y or n.";;
        esac
    done

done
