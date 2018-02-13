#!/usr/bin/python
# -*- coding: utf-8 -*-
import argparse, os
from transliterate import translit 
# require transliterate package, https://pypi.python.org/pypi/transliterate


def translit_file(path, lang='ru', to_latin=True):
    """
        This function can transliterate the alphabeta from 
        Armenian, Georgian, Greek, and Russian to Latin alphabeta
    Args:
        path: the path to input file
        lang: choose language, default russian
        to_latin: to latin or reverse, default true
    """
    dir_name = os.path.dirname(path)
    base_name = os.path.basename(path)
    out_base = 'trans_'+base_name
    out_path = os.path.join(dir_name, out_base)
    with open(path, 'r') as f_in, open(out_path, 'w') as f_out:
        for line in f_in:
            f_out.write(translit(line, lang, reversed=to_latin))



if __name__ == "__main__":
    