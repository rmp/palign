# palign: A toy genomic aligner #

Example usage:

## build an index ##

```
$ ./palign t/short_ref.fa 
Built hashtable in 0.001711 secs
```

## show database stats ##

```
$ ./palign --report
references: 1
hashes:     47
mappings:   47
```

## run a query ##
```
$ ./palign --query t/short_query.fa 
Reading t/short_query.fa
>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+full_match       [    0..61   ] ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT

>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+insertion        [    0..30   ] ACGACGCGACATCATCGCGCGATAGATCTGC
+insertion        [   33..64   ]                               CTAATCGCTCTAGATCGCCTAGACTCGCTGAT

>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+repeat           [    0..42   ] ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAG
+repeat           [   70..91   ]                                         TAGATCGCCTAGACTCGCTGAT

>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+deletion         [    0..23   ] ACGACGCGACATCATCGCGCGATA
+deletion         [   23..59   ]                          ATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT

>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+long_deletion    [    0..22   ] ACGACGCGACATCATCGCGCGAT
+long_deletion    [   22..45   ]                                       TCTAGATCGCCTAGACTCGCTGAT

>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+shortmatch       [    0..19   ]                     GATAGATCTGCTAATCGCTC

>shortref                        ACGACGCGACATCATCGCGCGATAGATCTGCTAATCGCTCTAGATCGCCTAGACTCGCTGAT
+snp              [    0..18   ] ACGACGCGACATCATCGCG
+snp              [   20..41   ]                     GATAGATCTGCTAATCGCTCTA
+snp              [   43..61   ]                                            ATCGCCTAGACTCGCTGAT

Aligned in 0.009004 secs
```
