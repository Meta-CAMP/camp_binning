import argparse
import glob
from os.path import abspath, basename, join
import pandas as pd
import numpy as np


def extract_lens(ctg_names, fasta):
    unb_raw_lst = []
    with open(abspath(fasta), 'r') as f:
        curr_len = 0
        unbinned = False
        for l in f:
            if l.startswith('>'):
                if unbinned: # If the previous contig was unbinned
                    unb_raw_lst.append(curr_len)
                unbinned = True if l.strip() not in ctg_names else False
                curr_len = 0
            else:
                if unbinned:
                    curr_len += len(l.strip())
    return unb_raw_lst
        

def main(args): # sample_name,binners,bin_num,num_ctgs,total_size,mean_bin_size,stdev_bin_size
    parts = args.in_dir.split('/')
    sample = parts[-2]
    binner = parts[-3]
    asm_name_lst = []
    with open(args.fasta, 'r') as f:
        for l in f:
            if l.startswith('>'):
                asm_name_lst.append(l.strip())
    bin_name_lst = []
    bin_stat_lst = []
    bin_len_lst = []
    for fi in glob.glob(join(args.in_dir, '*.fa')):
        if 'unbinned' in fi:
            continue
        bin_num = basename(fi).split('.')[1]
        with open(abspath(fi), 'r') as f:
            ctg_lens = []
            curr_name = ''
            curr_len = 0
            for l in f:
                if l.startswith('>'):
                    bin_name_lst.append(curr_name)
                    ctg_lens.append(curr_len)
                    bin_len_lst.append(curr_len)
                    curr_name = l.strip()
                    curr_len = 0
                else:
                    curr_len += len(l.strip())
            bin_name_lst.append(curr_name)
            ctg_lens.append(curr_len)
            bin_name_lst.pop(0)  # Remove the first empty string
            ctg_lens.pop(0)  # Remove the first 0
            bin_len_lst.pop(0) # Remove the first 0
            avg_ctg_len = sum(ctg_lens) / len(ctg_lens) if len(ctg_lens) > 0 else 0
            bin_stat_lst.append([sample, binner, bin_num, len(ctg_lens), sum(ctg_lens), avg_ctg_len, np.std(ctg_lens)])
    pd.DataFrame(bin_stat_lst).to_csv(join(args.out_dir, 'bin_stats.csv'), header = False, index = False)
    unbinned_name_lst = [n for n in asm_name_lst if n not in bin_name_lst]
    if 'NODE' in open(args.fasta, 'r').readline():  # MetaSPAdes contig naming scheme >NODE_1_length_28207_cov_4.594629
        unb_raw_lst = [int(i.split('_')[3]) for i in unbinned_name_lst]
    elif 'flag=1' in open(args.fasta, 'r').readline(): # MegaHIT contig naming scheme >k141_1046 flag=1 multi=4.0000 len=388
        unb_raw_lst = [int(i.split('_')[-1].split('=')[1]) for i in unbinned_name_lst]
    else: # Some other naming scheme
        unb_raw_lst = extract_lens(bin_name_lst, args.fasta)
    unb_len_lst = [l for l in unb_raw_lst if l > int(args.min_ctg_len)]
    asm_over_min = sum(bin_len_lst) + sum(unb_len_lst)
    avg_bin_size = sum(bin_len_lst) / len(bin_len_lst) if len(bin_len_lst) > 0 else 0
    avg_unb_size = sum(unb_len_lst) / len(unb_len_lst) if len(unb_len_lst) > 0 else 0
    with open(join(args.out_dir, 'bin_summ.csv'), 'w') as fo:
        fo.write('{},{},{},{},{},{},{},{},{},{},{},{}\n'.format(sample, binner, len(bin_len_lst), sum(bin_len_lst), sum(bin_len_lst) / asm_over_min, avg_bin_size, np.std(bin_len_lst), len(unb_len_lst), sum(unb_len_lst), sum(unb_len_lst) / asm_over_min, avg_unb_size, np.std(unb_len_lst)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fasta", help="Original assembly i.e.: all contigs (FastA)")
    parser.add_argument("min_ctg_len", help="Minimum contig length for binning (bp)")    
    parser.add_argument("in_dir", help="MAG directory")
    parser.add_argument("out_dir", help="Summary statistics of MAGs inferred from a sample by a binner")
    args = parser.parse_args()
    main(args)
