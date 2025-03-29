#!/bin/bash

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

show_welcome

# Set work_dir
DEFAULT_PATH=$PWD
read -p "Enter the working directory (Press Enter for default: $DEFAULT_PATH): " USER_WORK_DIR
BINNING_WORK_DIR="$(realpath "${USER_WORK_DIR:-$PWD}")"
echo "Working directory set to: $BINNING_WORK_DIR"
#echo "export ${BINNING_WORK_DIR} >> ~/.bashrc"


# Install MaxBin2
# === Step 1: Check if already installed ===
if command -v run_MaxBin.pl &> /dev/null; then
    MAXBIN_PATH=$(command -v run_MaxBin.pl)
    echo "✅ MaxBin2 is already installed at: $MAXBIN_PATH"
else
    echo "🧩 MaxBin2 not found. Proceeding with installation..."

    # === Step 2: Ask user for install location ===
    read -p "Enter installation directory for MaxBin2 [default: \$HOME/bin]: " USER_DIR
    BIN_DIR="${USER_DIR:-$HOME/bin}"
    mkdir -p "$BIN_DIR"
    echo "📦 Installing MaxBin2 to: $BIN_DIR"

    # === Step 3: Install MaxBin2 ===
    cd "$BIN_DIR"
    wget -O maxbin2.tar.gz https://sourceforge.net/projects/maxbin2/files/latest/download
    tar -xf maxbin2.tar.gz
    cd MaxBin-2.2.7/src
    make
    cd ../
    ./autobuild_auxiliary

    echo "📦 Installing IDBA-UD"
    wget https://github.com/loneknightpy/idba/releases/download/1.1.3/idba-1.1.3.tar.gz
    tar -xf idba-1.1.3.tar.gz
    cd idba-1.1.3/
    ./configure --prefix="$BIN_DIR/MaxBin-2.2.7/auxiliary/idba-1.1.3"
    make
    cd ../

    MAXBIN_PATH="$BIN_DIR/MaxBin-2.2.7/run_MaxBin.pl"
fi

# === Step 4: Export PATH ===
MAXBIN_DIR=$(dirname "$MAXBIN_PATH")
AUX_PATHS="$MAXBIN_DIR:$MAXBIN_DIR/auxiliary/FragGeneScan_1.30:$MAXBIN_DIR/auxiliary/hmmer-3.1b1/src:$MAXBIN_DIR/auxiliary/bowtie2-2.2.3:$MAXBIN_DIR/auxiliary/idba-1.1.3/bin"

echo ""
echo "📌 MaxBin2 installed!"

# === Prompt to export MaxBin2 PATHs to ~/.bashrc ===
echo ""
read -p "💡 Do you want to export MaxBin2 paths to your ~/.bashrc for future sessions? (Y/n): " RESPONSE
RESPONSE=${RESPONSE:-Y}  # Default to Yes

if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    echo "📦 Adding MaxBin2 paths to ~/.bashrc..."

    BASHRC="$HOME/.bashrc"
    AUX_PATHS=(
        "$MAXBIN_DIR"
        "$MAXBIN_DIR/auxiliary/FragGeneScan_1.30"
        "$MAXBIN_DIR/auxiliary/hmmer-3.1b1/src"
        "$MAXBIN_DIR/auxiliary/bowtie2-2.2.3"
        "$MAXBIN_DIR/auxiliary/idba-1.1.3/bin"
    )

    for path in "${AUX_PATHS[@]}"; do
        if ! grep -Fxq "export PATH=\$PATH:$path" "$BASHRC"; then
            echo "export PATH=\$PATH:$path" >> "$BASHRC"
            echo "✅ Added: $path"
        else
            echo "🟡 Already in .bashrc: $path"
        fi
        export PATH="$PATH:$path"  # Apply to current session too
    done

    echo "🔁 Done. Run 'source ~/.bashrc' to apply changes in new terminals."
else
    echo "⏭️ Skipping .bashrc export. You can manually add the paths later if needed."
fi


# Check and install conda envs: concoct, das_tool, metabinner, semibin, vamb, dataviz
cd $DEFAULT_PATH
DEFAULT_CONDA_ENV_DIR=$(conda info --base)/envs

# Function to check and install conda environments
check_and_install_env() {
    ENV_NAME=$1
    CONFIG_PATH=$2

    if conda env list | grep -q "$DEFAULT_CONDA_ENV_DIR/$ENV_NAME"; then
        echo "✅ Conda environment $ENV_NAME already exists."
    else
        echo "Installing Conda environment $ENV_NAME from $CONFIG_PATH..."
        CONDA_CHANNEL_PRIORITY=flexible conda env create -f "$CONFIG_PATH" || { echo "❌ Failed to install $ENV_NAME."; return; }
    fi
}

# Check and install 
check_and_install_env "concoct" "configs/conda/concoct.yaml"
check_and_install_env "das_tool" "configs/conda/das_tool.yaml"
check_and_install_env "dataviz" "configs/conda/dataviz.yaml"
check_and_install_env "metabinner" "configs/conda/metabinner.yaml"
check_and_install_env "semibin" "configs/conda/semibin.yaml"
check_and_install_env "vamb" "configs/conda/vamb.yaml"

declare -A DATABASE_PATHS

# Install CheckM1 databse
ask_checkm1() {
    local DB_NAME="CheckM1"
    local DB_VAR_NAME="CHECKM_PATH"
    local DB_HINT="/path/to/checkm_data_2015_01_16"
    local DB_PATH=""
    local DB_SUBDIR="checkm_data_2015_01_16"
    local ARCHIVE="checkm_data_2015_01_16.tar.gz"
    local DB_URL="https://data.ace.uq.edu.au/public/CheckM_databases/$ARCHIVE"

    echo "🛠️   Checking for $DB_NAME database..."

    while true; do
        read -p "❓ Do you already have $DB_NAME installed? (y/n): " RESPONSE
        case "$RESPONSE" in
            [Yy]* )
                while true; do
                    read -p "📂 Enter the path to your existing $DB_NAME database (e.g. $DB_HINT): " DB_PATH
                    if [[ -d "$DB_PATH" || -f "$DB_PATH" ]]; then
                        DATABASE_PATHS[$DB_VAR_NAME]="$DB_PATH"
                        echo "✅ $DB_NAME path set to: $DB_PATH"
                        return
                    else
                        echo "⚠️ The provided path does not exist or is invalid."
                        read -p "🔁 Re-enter path (r) or install $DB_NAME (i)? (r/i): " RETRY
                        if [[ "$RETRY" == "i" ]]; then
                            break
                        fi
                    fi
                done
                ;;
            [Nn]* | [Ii]* )
                read -p "📁 Enter install directory for $DB_NAME [default: \$HOME/databases]: " INSTALL_DIR
                INSTALL_DIR="${INSTALL_DIR:-$HOME/databases}"
                FINAL_DB_PATH="$INSTALL_DIR/$DB_SUBDIR"

                echo "📦 Installing $DB_NAME to: $FINAL_DB_PATH"
                mkdir -p "$FINAL_DB_PATH"
                wget -c "$DB_URL" -P "$INSTALL_DIR"
                tar -xzf "$INSTALL_DIR/$ARCHIVE" -C "$FINAL_DB_PATH"
                # Optionally: rm "$INSTALL_DIR/$ARCHIVE"
                echo "✅ $DB_NAME installed successfully!"

                DATABASE_PATHS[$DB_VAR_NAME]="$FINAL_DB_PATH"
                return
                ;;
            * ) echo "⚠️ Please enter 'y' or 'n'.";;
        esac
    done
}

ask_checkm1

# Create test_data/parameters.yaml
PARAMS_FILE="test_data/parameters.yaml"
# Remove existing parameters.yaml if present
[ -f "$PARAMS_FILE" ] && rm "$PARAMS_FILE"
EXT_PATH="$BINNING_WORK_DIR/workflow/ext"
DEFAULT_CONDA_ENV_DIR=$(conda info --base)/envs

echo "#'''Parameters config.'''#
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
# Test-only-values: '-e 2 -t 2 -q 1'
# Keep blank for actual runs
test_flags: '-e 2 -t 2 -q 1'


# --- semibin_binning --- #

model_environment: 'human_gut'


# --- maxbin2_binning --- #

maxbin2_script: '$MAXBIN_PATH'


# --- metabinner_binning --- #

metabinner_env: '$DEFAULT_CONDA_ENV_DIR/metabinner'
checkm1_db: '${DATABASE_PATHS[CHECKM_PATH]}'


# --- das_tool_refinement --- #

ext: '$EXT_PATH'
dastool_threshold: 0.5" > "$PARAMS_FILE"

echo "✅ parameters.yaml file created successfully in test_data/"

# Generate configs/parameters.yaml
SCRIPT_DIR=$(pwd)
PARAMS_FILE="configs/parameters.yaml"

echo "#'''Parameters config.'''#
conda_prefix: '$DEFAULT_CONDA_ENV_DIR'

# --- binning_algorithms --- #

min_contig_len:   2500


# --- metabat2_binning --- #

min_metabat_len:  2500


# --- concoct_binning --- #

fragment_size:    10000
overlap_size:     0


# --- vamb_binning --- #

min_bin_size: 500000
# Test-only-values: '-e 2 -t 2 -q 1'
# Keep blank for actual runs
test_flags: ''


# --- semibin_binning --- #

model_environment: 'human_gut'


# --- maxbin2_binning --- #

maxbin2_script: '$MAXBIN_PATH'


# --- metabinner_binning --- #

metabinner_env: '$DEFAULT_CONDA_ENV_DIR/metabinner'
checkm1_db: '$DATABASE_PATHS[$DB_VAR_NAME]'


# --- das_tool_refinement --- #

ext: '$EXT_PATH'
dastool_threshold: 0.5" > "$PARAMS_FILE"

# --- Generate test data input CSV ---

# Create test_data/samples.csv
INPUT_CSV="$DEFAULT_PATH/test_data/samples.csv"
MAG_QC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Generating test_data/samples.csv in $INPUT_CSV ..."

cat <<EOL > "$INPUT_CSV"
sample_name,mag_dir,bam
uhgg_metaspades,$DEFAULT_PATH/test_data/uhgg.metaspades.fasta,$DEFAULT_PATH/test_data/uhgg_1.fastq.gz,$DEFAULT_PATH/test_data/uhgg_2.fastq.gz
uhgg_megahit,$DEFAULT_PATH/test_data/uhgg.megahit.fasta,$DEFAULT_PATH/test_data/uhgg_1.fastq.gz,$DEFAULT_PATH/test_data/uhgg_2.fastq.gz
EOL

echo "✅ Test data input CSV created at: $INPUT_CSV"

echo "🎯 Setup complete! You can now test the workflow using \`python workflow/binning.py test\`"

