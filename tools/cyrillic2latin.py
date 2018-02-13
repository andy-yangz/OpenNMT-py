#!/usr/bin/python
# -*- coding: utf-8 -*-

# http://stackoverflow.com/questions/5574702/how-to-print-to-stderr-in-python
from __future__ import print_function
import sys
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

import errno
import exceptions
import unicodedata as ud
from os import walk, mkdir, path, error, listdir, getcwdu #, rename, unlink, remove
from os import name as os_name
from sys import argv, exit, getfilesystemencoding
import shutil



skip_hidden = True
replace_space =False
in_dir_suffix = u"_converted"

# This is close to "universal" conversion from http://translit.cc
conversion = {
        u'А': u'A',
        u'Б': u'B',
        u'В': u'V',
        u'Г': u'G',
        u'Д': u'D',
        u'Е': u'E',
        u'Ё': u'Jo',
        u'Ж': u'Zh',
        u'З': u'Z',
        u'И': u'I',
        u'Й': u'J',
        u'К': u'K',
        u'Л': u'L',
        u'М': u'M',
        u'Н': u'N',
        u'О': u'O',
        u'П': u'P',
        u'Р': u'R',
        u'С': u'S',
        u'Т': u'T',
        u'У': u'U',
        u'Ф': u'F',
        u'Х': u'H',
        u'Ц': u'Ts',
        u'Ч': u'Ch',
        u'Ш': u'Sh',
        u'Щ': u'Shh',
        u'Ъ': u"'",
        u'Ы': u'Y',
        u'Ь': u"'",
        u'Э': u'E',
        u'Ю': u'Ju',
        u'Я': u'Ja',
        }

conversion.update({k.lower(): v.lower() for k, v in conversion.iteritems()})

def cyr2lat(s):
    retval = u""
    s=ud.normalize('NFC',s)
    for c in s:
        if ord(c) > 128:
            try:
                c = conversion[c]
            except KeyError:
                c=u''
        elif replace_space and c == u' ':
            c = u'_'
        retval += c
    return retval


def solve_collisions_helper(v, v_c, seen, max_iter, change_name):
    removed = []
    for i, x in enumerate(v_c[:]):
        if x not in seen:
            seen.add(x)
        else:
            for n in xrange(1, 1 + max_iter):
                x_new = change_name(x, u"_" + unicode(n))
                if x_new not in seen:
                    seen.add(x_new)
                    v_c[i]=x_new
                    break
            else:
                removed.append(v[i])
                del(v_c[i])
                del(v[i])
    return removed

def change_filename(a, b):
    name, ext = path.splitext(a)
    return u"".join((name + b, ext))

def solve_collisions(dirs, nondirs, dirs_converted, nondirs_converted, max_iter=10):
    """A simple function to solve name collisions after conversion
    """
    seen = set()

    return solve_collisions_helper(dirs, dirs_converted, seen, max_iter, lambda a, b: a + b) + \
           solve_collisions_helper(nondirs, nondirs_converted, seen, max_iter, change_filename)



def walk_convert(top, topdown=True, onerror=None, followlinks=False,
                 convert=lambda n: n, solve_collisions=None,
                 on_removal=None, top_converted=None):
    """Directory tree generator with names conversion/transliteration support.
    convert is a function to convert (transliterate) a path.
    solve_collisions is a function to check and solve collisions in case convert
    function returns same values for different input. For example both "Йо" and
    "Ё" can be converted to "Yo". Collisions are not solved if it's None.
    It gets dirs, nondirs, dirs_converted, nondirs_converted lists and
    modifies *_converted lists to avoid collisions. It could also remove
    corresponding values from corresponding lists using del().
    It must return or an empty list or a list of removed names from dirs and
    nondirs.
    top_converted is for internal usage.
    on_removal(filename) is called if collision was not solved and a filename is
    removed
    Other parameters are the same as in os.walk
    Yelds 6-tuple with dirpath, dirnames, filenames, dirpath_converted,
    dirnames_converted, filenames_converted.
    Function code is slightly modified os.walk from python 2.7 os.py
    """

    islink, join, isdir = path.islink, path.join, path.isdir

    # We may not have read permission for top, in which case we can't
    # get a list of the files the directory contains.  os.path.walk
    # always suppressed the exception then, rather than blow up for a
    # minor reason when (say) a thousand readable directories are still
    # left to visit.  That logic is copied here.
    try:
        # Note that listdir and error are globals in this module due
        # to earlier import-*.
        names = listdir(top)
    except error, err:
        if onerror is not None:
            onerror(err)
        return

    dirs, nondirs = [], []
    for name in names:
        if isdir(join(top, name)):
            dirs.append(name)
        else:
            nondirs.append(name)

    if top_converted is None:
        top_converted=convert(top)

    dirs_c, nondirs_c = [convert(d) for d in dirs], [convert(nd) for nd in nondirs]


    if not solve_collisions is None:
        removed = solve_collisions(dirs, nondirs, dirs_c, nondirs_c)
        if not on_removal is None:
            for f in removed:
                on_removal(path.join(top, f))

    if topdown:
        yield top, dirs, nondirs, top_converted, dirs_c, nondirs_c
    for name, name_c in zip(dirs, dirs_c):
        new_path = join(top, name)
        new_path_c = join(top_converted, name_c)
        if followlinks or not islink(new_path):
            for x in walk_convert(new_path, topdown, onerror, followlinks,
                                  convert, solve_collisions, on_removal,
                                  top_converted=new_path_c):
                yield x
    if not topdown:
        yield top, dirs, nondirs, top_converted, dirs_c, nondirs_c



# http://stackoverflow.com/questions/7099290/how-to-ignore-hidden-files-using-os-listdir
if os_name == 'nt':
    import win32api, win32con
def file_is_hidden(p):
    if os_name== 'nt':
        attribute = win32api.GetFileAttributes(p)
        return attribute & (win32con.FILE_ATTRIBUTE_HIDDEN | win32con.FILE_ATTRIBUTE_SYSTEM)
    else:
        return p.startswith('.')

if len(argv) == 1:
    print(u"Usage: {} <dirs>".format(argv[0]))
    exit(-1)

def create_directory(dir_path):
    """
    """
    if not path.exists(dir_path):
            mkdir(dir_path)
            print(u"Create \"{}\"".format(dir_path))
    else:
        if not path.isdir(dir_path):
            eprint(u"Can't create directory \"{}\" – there is a file already.".format(dir_path))
            return False
        else:
            print(u"Skip \"{}\"".format(dir_path))
    return True


def on_file_removal(fn):
    eprint(u"Can't find a new name for a conflicting file \"{}\".".format(fn))

if __name__ == "__main__":
    for i, in_dir in enumerate(argv[1:]):
        try:
            in_dir = in_dir.decode(getfilesystemencoding())
        except:
            eprint(u"Failed to convert argument {} to unicode string".format(in_dir))
        else:
            # try to create top directory, convert the deepest directory name only
            in_dir=path.normpath(in_dir)

            if in_dir==u".":
                in_dir=path.normpath(getcwdu())
            elif in_dir==u"..":
                in_dir=path.dirname(path.normpath(getcwdu()))

            in_dir_splitted=path.split(in_dir)
            in_dir_c=path.join(in_dir_splitted[0], cyr2lat(in_dir_splitted[1]))

            if in_dir == in_dir_c:
                in_dir_c = path.join(in_dir_splitted[0], in_dir_splitted[1] + in_dir_suffix)

            if create_directory(in_dir_c):
                # walk and convert directory tree
                for top, dnames, fnames, top_c, dnames_c, fnames_c in walk_convert(in_dir,  convert=cyr2lat,
                                                                                   solve_collisions=solve_collisions,
                                                                                   on_removal=on_file_removal,
                                                                                   top_converted=in_dir_c):
                    # Create new directories first
                    for i, (d, d_c) in enumerate(zip(dnames[:], dnames_c[:])):
                        d_c_path = path.join(top_c, d_c)

                        if (skip_hidden and file_is_hidden(d)) or not create_directory(d_c_path):
                            # do not walk hidden directories and do not walk
                            # directories if their converted names conflict with
                            # existent files
                            del(dnames[i])
                            del(dnames_c[i])

                    # Copy files with new names
                    for f, f_c in zip(fnames, fnames_c):
                        if skip_hidden and file_is_hidden(f):
                            continue
                        f_path = path.join(top, f)
                        f_c_path = path.join(top_c, f_c)

                        try:
                            shutil.copyfile(f_path, f_c_path)
                        except shutil.Error:
                            eprint(u"Can't copy file \"{}\" to itself.".format(f_path))
                        except IOError:
                            eprint(u"Can't copy file to \"{}\".".format(f_c_path))
                        else:
                            print(u"Copy to \"{}\"".format(f_c_path))