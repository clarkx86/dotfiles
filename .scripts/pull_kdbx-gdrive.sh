#!bin/bash
VERSION="1.0.0"
# Author: 	Clark Stühmer
# Description:	This script pulls a file from a remote server as a temporary file and opens it.
# Synopsis:
#	sh pull_kdbx-gdrive.sh -i -u -n <GDRIVE DIR> <REMOTE FILEPATH>
# Arguments:
#	-r | --remote
#	The remote provider to use. Valid providers are:
#	gdrive
#	-i | --interactive
#	Prompts the user whether to upload the temporary *.kdbx file back to the
#	remote after closing it, given that the database has been modified.
#	When prompted, "y" simply uploads and overwrites the file,
#	while "Y" additionaly creates a backup of the previous file on the remote.
#	-u | --upload
#	Uploads the file back to the remote server if changes were made
#	and overwrites the previous revision after creating a backup on the remote.
#	This overwrites the -i flag.
#	-n | --no-backup
#	Forces this script to not create a backup on the remote when "-u" is specified.
#	-c
#	Command to execute when opening the file.

TEMP_DIR="$(dirname $0)/tmp"
TEMP_DB_PATH="$TEMP_DIR/.db.kdbx"

# DEFAULT CONFIGURATION
ARG_BACKUP=1
ARG_REMOTE_PATH='/Documents/Private/Database.kdbx'

# Parse user parameters
i=1
while [ ! -z ${!i} ]; do
	j=$(($i+1))

	case ${!i} in
		"-r") ;&
		"--remote") ARG_REMOTE="${!j}"
		;;
		"-i") ;&
		"--interactive") ARG_INTERACTIVE=1
		;;
		"-u") ;&
		"--upload") ARG_UPLOAD=1
		;;
		"-n") ;&
		"--no-backup") unset ARG_BACKUP
		;;
		"-c") ARG_COMMAND="${!j}"
		;;
	esac

	i=$j
done

function rmTmpDb {
	# Check if previous *.kdbx exists
	if [[ -f $TEMP_DB_PATH ]]; then
		printf "Removing ${1}temporary file...\n"
		rm $TEMP_DB_PATH
	fi
}

###
if [[ -z $ARG_REMOTE ]]; then
	echo "Remote not specified..."
	exit 1
fi

if [[ -z $ARG_REMOTE_PATH ]]; then
	echo "Path to remote file not specified..."
	exit 1
fi

# Create temporary directory
if [[ ! -d $TEMP_DIR ]]; then
	mkdir $TEMP_DIR
fi

rmTmpDb "previous "

printf "Pulling file from remote...\n"
rclone copyto "${ARG_REMOTE}:${ARG_REMOTE_PATH}" "${TEMP_DB_PATH}"
# Generate checksum of unmodified file
CHECKSUM=$(md5sum $TEMP_DB_PATH)
# Execute KeePass
$ARG_COMMAND $TEMP_DB_PATH

if [[ $CHECKSUM != $(md5sum $TEMP_DB_PATH) ]]; then
	echo -e "\e[31mLocal file has been modified.\e[0m"

	if [[ -n $ARG_INTERACTIVE ]]; then
		printf "Do you want to upload the file back to the remote? (Y/y/n): " && read RESULT
		case $RESULT in
			"y")	unset ARG_BACKUP
				;&
			"Y")	ARG_UPLOAD=1
				;;
		esac
	fi

	if [[ -n $ARG_UPLOAD ]]; then
		if [[ -n $ARG_BACKUP ]]; then
			printf "Creating copy on remote...\n"
			REMOTE_COPY_PATH=$(dirname "$ARG_REMOTE_PATH")/$(date +'%Y-%m-%d_%H-%M-%S')_$(basename "$ARG_REMOTE_PATH")
			rclone copyto "${ARG_REMOTE}:${ARG_REMOTE_PATH}" "${ARG_REMOTE}:${REMOTE_COPY_PATH}"
			rclone delete "${ARG_REMOTE}:${ARG_REMOTE_PATH}"
		fi

		printf "Pushing file to remote...\n"
		pushd "$ARG_GDRIVE_DIR" 1> /dev/null
		#echo "/$ARG_REMOTE_PATH.bak"
		rclone copyto "${TEMP_DB_PATH}" "${ARG_REMOTE}:${ARG_REMOTE_PATH}"
		popd 1> /dev/null
	fi
else
	echo "File has not been modified."
fi

rmTmpDb

echo "All done! Goodbye."
