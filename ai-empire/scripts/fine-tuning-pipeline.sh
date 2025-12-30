#!/bin/bash

################################################################################
# Fine-Tuning Data Pipeline
# Collects inference data and prepares datasets for model training
################################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

DATASET_DIR="/opt/ai-empire/datasets"
DB_NAME="ai_empire"
DB_USER="postgres"
DB_HOST="localhost"

# Create dataset directory
mkdir -p "$DATASET_DIR"/{raw,processed,training}

collect_inference_data() {
    print_info "Collecting inference data from PostgreSQL..."

    # Export recent inference logs
    psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
        COPY (
            SELECT
                pattern,
                input_text,
                output_text,
                model_used,
                created_at
            FROM inference_logs
            WHERE created_at >= NOW() - INTERVAL '24 hours'
                AND output_text IS NOT NULL
            ORDER BY created_at DESC
        ) TO STDOUT WITH CSV HEADER
    " > "$DATASET_DIR/raw/inference_$(date +%Y%m%d).csv"

    local count=$(wc -l < "$DATASET_DIR/raw/inference_$(date +%Y%m%d).csv")
    print_success "Collected $count inference samples"
}

preprocess_with_fabric() {
    print_info "Preprocessing data with Fabric create_alpaca_dataset pattern..."

    local input_file="$DATASET_DIR/raw/inference_$(date +%Y%m%d).csv"
    local output_file="$DATASET_DIR/processed/alpaca_$(date +%Y%m%d).json"

    # Convert CSV to Alpaca format using Fabric
    while IFS=, read -r pattern input output model timestamp; do
        if [ "$pattern" != "pattern" ]; then  # Skip header
            echo "{\"instruction\": \"$pattern\", \"input\": \"$input\", \"output\": \"$output\"}" >> "$output_file.tmp"
        fi
    done < "$input_file"

    # Wrap in array and format
    echo "[" > "$output_file"
    cat "$output_file.tmp" | sed '$!s/$/,/' >> "$output_file"
    echo "]" >> "$output_file"

    rm -f "$output_file.tmp"

    local count=$(jq '. | length' "$output_file")
    print_success "Created Alpaca dataset with $count samples"
}

filter_quality_samples() {
    print_info "Filtering high-quality samples..."

    local input_file="$DATASET_DIR/processed/alpaca_$(date +%Y%m%d).json"
    local output_file="$DATASET_DIR/training/alpaca_filtered_$(date +%Y%m%d).json"

    # Filter samples where output length > 100 chars (basic quality check)
    jq '[.[] | select((.output | length) > 100)]' "$input_file" > "$output_file"

    local filtered_count=$(jq '. | length' "$output_file")
    print_success "Filtered to $filtered_count high-quality samples"
}

merge_historical_data() {
    print_info "Merging with historical training data..."

    local output_file="$DATASET_DIR/training/complete_dataset_$(date +%Y%m%d).json"

    # Combine all filtered datasets
    jq -s 'add' "$DATASET_DIR/training"/alpaca_filtered_*.json > "$output_file"

    local total_count=$(jq '. | length' "$output_file")
    print_success "Complete dataset: $total_count samples"

    # Keep only last 30 days of data
    find "$DATASET_DIR/raw" -name "*.csv" -mtime +30 -delete
    find "$DATASET_DIR/processed" -name "*.json" -mtime +30 -delete
}

prepare_for_training() {
    print_info "Preparing dataset for fine-tuning..."

    local input_file="$DATASET_DIR/training/complete_dataset_$(date +%Y%m%d).json"
    local train_file="$DATASET_DIR/training/train.json"
    local val_file="$DATASET_DIR/training/val.json"

    # Split 90/10 train/validation
    total=$(jq '. | length' "$input_file")
    train_count=$((total * 90 / 100))

    jq ".[:$train_count]" "$input_file" > "$train_file"
    jq ".[$train_count:]" "$input_file" > "$val_file"

    print_success "Training set: $(jq '. | length' "$train_file") samples"
    print_success "Validation set: $(jq '. | length' "$val_file") samples"
}

export_to_ollama_modelfile() {
    print_info "Creating Ollama Modelfile for fine-tuning..."

    local modelfile="$DATASET_DIR/training/Modelfile"

    cat > "$modelfile" << EOF
FROM deepseek-r1:8b

# Fine-tuned on AI Empire inference data
# Generated: $(date)

SYSTEM """
You are a helpful AI assistant that has been fine-tuned on production data
from the AI Empire system. You excel at content extraction, summarization,
and knowledge synthesis.
"""

# Temperature optimized for consistent output
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER top_k 40
EOF

    print_success "Modelfile created: $modelfile"
    print_info "To create fine-tuned model: ollama create ai-empire-ft -f $modelfile"
}

show_statistics() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              FINE-TUNING PIPELINE SUMMARY                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    local train_samples=$(jq '. | length' "$DATASET_DIR/training/train.json" 2>/dev/null || echo "0")
    local val_samples=$(jq '. | length' "$DATASET_DIR/training/val.json" 2>/dev/null || echo "0")
    local total=$((train_samples + val_samples))

    echo "Dataset Statistics:"
    echo "  Training samples:   $train_samples"
    echo "  Validation samples: $val_samples"
    echo "  Total samples:      $total"
    echo ""

    echo "Storage:"
    echo "  Raw data:       $(du -sh "$DATASET_DIR/raw" 2>/dev/null | cut -f1 || echo '0')"
    echo "  Processed data: $(du -sh "$DATASET_DIR/processed" 2>/dev/null | cut -f1 || echo '0')"
    echo "  Training data:  $(du -sh "$DATASET_DIR/training" 2>/dev/null | cut -f1 || echo '0')"
    echo ""

    echo "Next Steps:"
    echo "  1. Review datasets in: $DATASET_DIR/training/"
    echo "  2. Start fine-tuning: ollama create ai-empire-ft -f $DATASET_DIR/training/Modelfile"
    echo "  3. Test model: ollama run ai-empire-ft"
    echo ""
}

# Main pipeline
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           AI EMPIRE FINE-TUNING DATA PIPELINE               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    collect_inference_data
    preprocess_with_fabric
    filter_quality_samples
    merge_historical_data
    prepare_for_training
    export_to_ollama_modelfile
    show_statistics
}

main "$@"
