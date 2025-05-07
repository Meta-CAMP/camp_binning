#!/bin/bash

# --- Functions ---

show_welcome() {
    clear  # Clear the screen for a clean look

    echo ""
    sleep 0.2
    echo " _   _      _ _          ____    _    __  __ ____           _ "
    sleep 0.2
    echo "| | | | ___| | | ___    / ___|  / \  |  \/  |  _ \ ___ _ __| |"
    sleep 0.2
    echo "| |_| |/ _ \ | |/ _ \  | |     / _ \ | |\/| | |_) / _ \ '__| |"
    sleep 0.2
    echo "|  _  |  __/ | | (_) | | |___ / ___ \| |  | |  __/  __/ |  |_|"
    sleep 0.2
    echo "|_| |_|\___|_|_|\___/   \____/_/   \_\_|  |_|_|   \___|_|  (_)"
    sleep 0.5

    echo ""
    echo "🌲🏕️     WELCOME TO CAMP SETUP! 🏕️   🌲"
    echo "===================================================="
    echo ""
    echo "   🏕️     Configuring Databases & Conda Environments"
    echo "       for CAMP MAG binning"
    echo ""
    echo "   🔥 Let's get everything set up properly!"
    echo ""
    echo "===================================================="
    echo ""

}

# Check to see if the base CAMP environment has already been installed 
find_install_camp_env() {
    if conda env list | grep -q "$DEFAULT_CONDA_ENV_DIR/camp"; then 
        echo "✅ The main CAMP environment is already installed in $DEFAULT_CONDA_ENV_DIR."
    else
        echo "🚀 Installing the main CAMP environment in $DEFAULT_CONDA_ENV_DIR/..."
        conda create --prefix "$DEFAULT_CONDA_ENV_DIR/camp" -c conda-forge -c bioconda biopython blast bowtie2 bumpversion click click-default-group cookiecutter jupyter matplotlib numpy pandas samtools scikit-learn scipy seaborn snakemake umap-learn upsetplot
        echo "✅ The main CAMP environment has been installed successfully!"
    fi
}

# Check to see if the required conda environments have already been installed 
find_install_conda_env() {
    if conda env list | grep -q "$DEFAULT_CONDA_ENV_DIR/$1"; then
        echo "✅ The $1 environment is already installed in $DEFAULT_CONDA_ENV_DIR."
    else
        echo "🚀 Installing $1 in $DEFAULT_CONDA_ENV_DIR/$1..."
        conda create --prefix $DEFAULT_CONDA_ENV_DIR/$1 -c conda-forge -c bioconda $1
        echo "✅ $1 installed successfully!"
}

# Ask user if each database is already installed or needs to be installed
ask_database() {
    local DB_NAME="$1"
    local DB_VAR_NAME="$2"
    local DB_PATH=""

    echo "🛠️  Checking for $DB_NAME database..."

    while true; do
        read -p "❓ Do you already have $DB_NAME installed? (y/n): " RESPONSE
        case "$RESPONSE" in
            [Yy]* )
                while true; do
                    read -p "📂 Enter the path to your existing $DB_NAME database (eg. /path/to/database_storage): " DB_PATH
                    if [[ -d "$DB_PATH" || -f "$DB_PATH" ]]; then
                        DATABASE_PATHS[$DB_VAR_NAME]="$DB_PATH"
                        echo "✅ $DB_NAME path set to: $DB_PATH"
                        return  # Exit the function immediately after successful input
                    else
                        echo "⚠️ The provided path does not exist or is empty. Please check and try again."
                        read -p "Do you want to re-enter the path (r) or install $DB_NAME instead (i)? (r/i): " RETRY
                        if [[ "$RETRY" == "i" ]]; then
                            break  # Exit inner loop to start installation
                        fi
                    fi
                done
                if [[ "$RETRY" == "i" ]]; then
                    break  # Exit outer loop to install the database
                fi
                ;;
            [Nn]* )
                read -p "📂 Enter the directory where you want to install $DB_NAME: " DB_PATH
                install_database "$DB_NAME" "$DB_VAR_NAME" "$DB_PATH"
                return  # Exit function after installation
                ;;
            * ) echo "⚠️ Please enter 'y(es)' or 'n(o)'.";;
        esac
    done
}

# Install databases in the specified directory
install_database() {
    local DB_NAME="$1"
    local DB_VAR_NAME="$2"
    local INSTALL_DIR="$3"
    local FINAL_DB_PATH="$INSTALL_DIR/${DB_SUBDIRS[$DB_VAR_NAME]}"

    echo "🚀 Installing $DB_NAME database in: $FINAL_DB_PATH"	

    case "$DB_VAR_NAME" in
        "checkm1")
            local ARCHIVE="checkm_data_2015_01_16.tar.gz"
            local DB_URL="https://data.ace.uq.edu.au/public/CheckM_databases/$ARCHIVE"
            wget -c $DB_URL -P $INSTALL_DIR
	        tar -xzf "$INSTALL_DIR/$ARCHIVE.tar.gz" -C "$FINAL_DB_PATH"
            echo "✅ CheckM1 database installed successfully!"
            ;;
        "DATABASE_2_PATH")
            wget https://repository2.com/database_2.tar.gz -P $INSTALL_DIR
	        mkdir -p $FINAL_DB_PATH
            tar -xzf "$INSTALL_DIR/database_2.tar.gz" -C "$FINAL_DB_PATH"
            echo "✅ Database 2 installed successfully!"
            ;;
        *)
            echo "⚠️ Unknown database: $DB_NAME"
            ;;
    esac

    DATABASE_PATHS[$DB_VAR_NAME]="$FINAL_DB_PATH"
}

# --- Initialize setup ---

show_welcome

# Set work_dir
MODULE_WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
read -p "Enter the working directory (Press Enter for default: $DEFAULT_PATH): " USER_WORK_DIR
BINNING_WORK_DIR="$(realpath "${USER_WORK_DIR:-$PWD}")"
echo "Working directory set to: $BINNING_WORK_DIR"
#echo "export ${BINNING_WORK_DIR} >> ~/.bashrc"

# Find or install...

# --- Install conda environments ---

cd $BINNING_WORK_DIR
DEFAULT_CONDA_ENV_DIR=$(conda info --base)/envs

# ...module environment
find_install_camp_env

# ...auxiliary environments
MODULE_PKGS=('metabat2' 'concoct' 'maxbin2' 'semibin' 'metabinner' 'vamb' 'das_tool') # Add any additional conda packages here
for m in "${MODULE_PKGS[@]}"; do
    find_install_conda_env "$m"
done

# --- Download databases ---

# Default database locations relative to $INSTALL_DIR
declare -A DB_SUBDIRS=(
    ["checkm1"]="checkm_data_2015_01_16"
)

# Absolute database paths (to be set in install_database)
declare -A DATABASE_PATHS

# Ask for all required databases
ask_database "CheckM 1" "checkm1"

# --- Generate parameter configs ---

# Default values for analysis parameters
EXT_PATH="$MODULE_WORK_DIR/workflow/ext"  # Assuming extensions are in workflow/ext

# Create test_data/parameters.yaml
PARAMS_FILE="$MODULE_WORK_DIR/test_data/parameters.yaml" 
# Remove existing parameters.yaml if present
[ -f "$PARAMS_FILE" ] && rm "$PARAMS_FILE"

echo "🚀 Generating test_data/parameters.yaml in $PARAMS_FILE ..."

cat <<EOL > "$PARAMS_FILE"
#'''Parameters config.'''#

ext: '$EXT_PATH'
conda_prefix: '$DEFAULT_CONDA_ENV_DIR'

# --- binning_algorithms --- #

min_contig_len:   500


# --- metabat2_binning --- #

min_metabat_len:  1500


# --- concoct_binning --- #

fragment_size:    1500
overlap_size:     0


# --- vamb_binning --- #

min_bin_size: 100
test_flags: '-e 2 -t 2 -q 1'


# --- semibin_binning --- #

model_environment: 'human_gut'


# --- metabinner_binning --- #

metabinner_env: '$DEFAULT_CONDA_ENV_DIR/metabinner'
checkm1_db: '${DATABASE_PATHS[checkm1]}'


# --- das_tool_refinement --- #

dastool_threshold: 0.5 
EOL

echo "✅ Test data parameter configuration file created at: $PARAMS_FILE"

# Create configs/parameters.yaml 
PARAMS_FILE="$MODULE_WORK_DIR/configs/parameters.yaml"

cat <<EOL > "$PARAMS_FILE"
#'''Parameters config.'''#

ext: '$EXT_PATH'
conda_prefix: '$DEFAULT_CONDA_ENV_DIR'

# --- binning_algorithms --- #

min_contig_len:   2500


# --- metabat2_binning --- #

min_metabat_len:  2500


# --- concoct_binning --- #

fragment_size:    2500
overlap_size:     1000


# --- vamb_binning --- #

min_bin_size:     100000
test_flags:       ''


# --- semibin_binning --- #

model_environment: 'human_gut'


# --- metabinner_binning --- #

metabinner_env: '$DEFAULT_CONDA_ENV_DIR/metabinner'
checkm1_db:     '${DATABASE_PATHS[checkm1]}'


# --- das_tool_refinement --- #

dastool_threshold: 0.5 
EOL

# --- Generate test data input CSV ---

# Create test_data/samples.csv
INPUT_CSV="$MODULE_WORK_DIR/test_data/samples.csv" 

echo "🚀 Generating test_data/samples.csv in $INPUT_CSV ..."

cat <<EOL > "$INPUT_CSV"
sample_name,illumina_ctg,illumina_fwd,illumina_rev
uhgg_metaspades,$MODULE_WORK_DIR/test_data/uhgg.metaspades.fasta,$MODULE_WORK_DIR/test_data/uhgg_1.fastq.gz,$MODULE_WORK_DIR/test_data/uhgg_2.fastq.gz
uhgg_megahit,$MODULE_WORK_DIR/test_data/uhgg.megahit.fasta,$MODULE_WORK_DIR/test_data/uhgg_1.fastq.gz,$MODULE_WORK_DIR/test_data/uhgg_2.fastq.gz
EOL

echo "✅ Test data input CSV created at: $INPUT_CSV"

echo "🎯 Setup complete! You can now test the workflow using \`python workflow/binning.py test\`"

