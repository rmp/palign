# palign: A toy genomic aligner #

Example usage:
```
# build an index
$ ./palign --index t/short_ref.fa 
Built hashtable in 0.001711 secs

# run a query
$ ./palign --index index.stbl --query t/short_query.fa 
>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+full_match       [    0..61   ] ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT

>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+insertion        [    0..30   ] ACGACGCGACATCATCGCGCGATAGATCTGC
+insertion        [   33..64   ]                               CTAATCGCTCTAGATCGCCTAGACTCGCTGAT

>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+deletion         [    0..23   ] ACGACGCGACATCATCGCGCGATA
+deletion         [   23..59   ]                          ATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT

>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+long_deletion    [    0..22   ] ACGACGCGACATCATCGCGCGAT
+long_deletion    [   22..45   ]                                       TCTAGATCGCCTAGACTCGCTGAT


>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+shortmatch       [    0..19   ]                     GATAGATCTGCTAATCGCTC

Aligned in 0.001935 secs
```
