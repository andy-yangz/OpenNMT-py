#!/usr/bin/perl

##################################################################
# Copyright (C) 1998 Stefan Mashkevich <mash@mashke.org>
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License.
# Disclaimer: The program is provided "as is" and there is no
# warranty of any kind whatsoever. Your using it is at your own risk.
##################################################################
# Transliterating from KOI8, DOS866, WIN1251, ISO8859-5, MAC
# into any of these or into Latin characters
# Manually: between two given encodings
# Automatically: into a given encoding, figuring out the initial one
# automatically by frequency analysis
#
# v0.1 S.Mashkevich  16 Nov 1998
#      first working version
# v0.5 S.Mashkevich  26 Nov 1998
#      redesigned and shortened main code
#      completely rewrote frequency analysis algorithm
#      added MAC, ISO, Ukrainian and Belorussian characters
# v0.8 S.Mashkevich  13 Dec 1998
#      added reverse transliteration (handled by separate script;
#      this script was not changed)
#
# text on standard input, recoded on standard output
# see usage message
#
##################################################################
# encodings:
# KOI8  DOS866(=ALT)  WIN1251  MAC  ISO8859-5  Latin(=translit)

@intos = qw/k a w m i l/;

$ncods = @intos - 1;  #  last = Latin, treated separately
##################################################################
# read in character codes

while (<DATA>) {
    /^\d/ && do {
	@data = split;
	for $j (0..$ncods-1) {
	    $chars{$intos[$j]} = join '', $chars{$intos[$j]}, chr($data[$j]);
	    $latin{chr($data[$0])} = $data[$ncods];
	    }
    }
}

##################################################################
# determine what to do

@args = split //, $ARGV[0]; 

# into what
$into = pop @args || usage();
# If Latin, will recode into 0 and raise flag to re-recode later on
$into eq $intos[$ncods] && do {$into = $intos[0]; $latflag = 1};
$chars_into = $chars{$into} || usage();

# from what (or automatic)
defined ($from = pop @args) ?
    ($chars_from = $chars{$from} || usage()) :
    ($automatic = 1) ;

# there shouldn't be anything else in the argument
defined (pop @args) && usage();

##################################################################
# actual recoding

undef $/;
$_ = <STDIN>;

# analyze if necessary
defined ($automatic) && do {
    $result = &analyze;
    do {print; exit} unless ($result);   # probably non-Russian text
    $chars_from = $chars{$result};
    };
    
# transliterate
eval "tr/$chars_from/$chars_into/, 1" || die $@;

# if it was Latin
defined ($latflag) && do {
    foreach $char (keys %latin) {
	s/$char/$latin{$char}/g;
	};
    };

# output
print;

##################################################################
sub analyze {

# Frequency analyzer of Russian texts
# attempting to determine which encoding they are in
# Returns 0 if $_ appears to be non-Russian text
# or one of k,a,w,m,i as it deems $_ is in
# Things really depend on specific features of the encodings here,
# therefore I don't care to avoid hardwired "magic constants"

# first, count how many (perhaps) Russian characters are there
my $intrst_chars = join '', map(chr, 128..255);
my $length = eval "tr /$intrst_chars/$intrst_chars/";

# threshold for deciding when there are "too few" frequent characters in it
my $thrhold = 0.08;

# letters we will use: a,e,i,o,A,E,I,O
my %aeio, %num_aeio, $enc_aieo, %AEIO, %num_AEIO, $enc_AIEO, $enc;
my $num_aeio_max = 0, $num_AIEO_max = 0;
$aeio{k} = join '', map(chr, qw/193 197 201 207/);
$aeio{a} = join '', map(chr, qw/160 165 168 174/);
$aeio{w} = join '', map(chr, qw/224 229 232 238/);
$aeio{i} = join '', map(chr, qw/208 213 216 222/);
$AEIO{k} = join '', map(chr, qw/225 229 233 239/);
$AEIO{a} = join '', map(chr, qw/128 133 136 142/);
$AEIO{w} = join '', map(chr, qw/192 197 200 206/);
$AEIO{i} = join '', map(chr, qw/176 181 184 190/);

# Count how many times there are "a, e, i, o"
for $enc (qw/k a w i/) {
    $num_aeio{$enc} = eval "tr/$aeio{$enc}/$aeio{$enc}/";
    $num_aeio{$enc} > $num_aeio_max  &&  do {
	$num_aeio_max = $num_aeio{$enc}; $enc_aeio = $enc
	}
    };

# suppose we found them (relative number more than $freqthr)
$num_aeio_max > $thrhold * $length  &&  do {
    # if 'a', no doubt
    $enc_aeio eq 'a'  &&  return 'a';
    # if 'k' or 'i', might really be 'w' capitals; check this
    ($enc_aeio eq 'k' || $enc_aeio eq 'i')  &&  do {
	$num_AEIO{w} = eval "tr/$AEIO{w}/$AEIO{w}/";
	$num_AEIO{w} > $num_aeio_max  ?  return 'w'  :  return $enc_aeio
	};
    # otherwise (i.e 'w') decide between 'w' and 'm' using caps
    my $wincaps = join '', map(chr, 192..223);
    my $maccaps = join '', map(chr, 128..159);
    my $num_wincaps = eval "tr/$wincaps/$wincaps/";
    my $num_maccaps = eval "tr/$maccaps/$maccaps/";
    $num_maccaps > $num_wincaps  ?  return 'm'  :  return 'w'
};

# If not, maybe it is in all capitals;
# count how many times there are "A, E, I, O"
for $enc (qw/k a w i/) {
    $num_AEIO{$enc} = eval "tr/$AEIO{$enc}/$AEIO{$enc}/";
    $num_AEIO{$enc} > $num_AEIO_max  &&  do {
	$num_AEIO_max = $num_AEIO{$enc}; $enc_AEIO = $enc
	}
    };

# suppose we found them (relative number more than $freqthr)
$num_AEIO_max > $thrhold * $length  &&  do {
    # Makes no sense to look for possible confusion with smalls.
    # It only remains to distinguish between 'a' and 'm'
    $enc_AEIO ne 'a'  &&  return $enc_AEIO;
    # to distinguish, first try smalls
    my $altsmalls = join '', map(chr, 160..175), map(chr, 224..239);
    my $macsmalls = join '', map(chr, 224..255);
    my $num_altsmalls = eval "tr/$altsmalls/$altsmalls/";
    my $num_macsmalls = eval "tr/$macsmalls/$macsmalls/";
    $num_altsmalls > $num_macsmalls  &&  return 'a';
    $num_macsmalls > $num_altsmalls  &&  return 'm';
    # if this doesn't work, try "YO", Ukrainian & Belorussian caps
    my $altmorecaps = join '', map(chr, qw/240 242 244 246 248 250/);
    my $macmorecaps = join '', map(chr, qw/221 162 184 167 186 216/);
    my $num_altmorecaps = eval "tr/$altmorecaps/$altmorecaps/";
    my $num_macmorecaps = eval "tr/$macmorecaps/$macmorecaps/";
    # if even this fails, return 'a' and hope they won't notice ;-)
    $num_macmorecaps > $num_altmorecaps  ?  return 'm'  :  return 'a'
};

# if all the above fails, we don't know what it is; return nothing
return 0;

}


##################################################################
sub usage { die
"Usage: cyr-conv <xy> converts from x into y
       cyr-conv <y> automatically converts into y
x = [kawmi], y = [kawmil] (KOI/ALT/WIN/MAC/ISO/Latin)\n"
}

##################################################################
__END__
KOI   ALT   WIN   MAC   ISO    Latin
225   128   192   128   176    A
226   129   193   129   177    B
247   130   194   130   178    V
231   131   195   131   179    G
228   132   196   132   180    D
229   133   197   133   181    E
246   134   198   134   182    ZH
250   135   199   135   183    Z
233   136   200   136   184    I
234   137   201   137   185    J
235   138   202   138   186    K
236   139   203   139   187    L
237   140   204   140   188    M
238   141   205   141   189    N
239   142   206   142   190    O
240   143   207   143   191    P
242   144   208   144   192    R
243   145   209   145   193    S
244   146   210   146   194    T
245   147   211   147   195    U
230   148   212   148   196    F
232   149   213   149   197    KH
227   150   214   150   198    TS
254   151   215   151   199    CH
251   152   216   152   200    SH
253   153   217   153   201    SCH
255   154   218   154   202    '       # HARD SIGN
249   155   219   155   203    Y
248   156   220   156   204    '       # SOFT SIGN
252   157   221   157   205    E       # REVERSE E
224   158   222   158   206    YU
241   159   223   159   207    YA
179   240   168   221   161    YO
178   242   165   162   179    G       # UKRAINIAN G WITH HOOK
180   244   170   184   164    YE      # UKRAINIAN YE
182   246   178   167   166    I       # UKRAINIAN I
183   248   175   186   167    YI      # UKRAINIAN YI
188   250   161   216   174    U       # BELORUSSIAN SHORT U
193   160   224   224   208    a
194   161   225   225   209    b
215   162   226   226   210    v
199   163   227   227   211    g
196   164   228   228   212    d
197   165   229   229   213    e
214   166   230   230   214    zh
218   167   231   231   215    z
201   168   232   232   216    i
202   169   233   233   217    j
203   170   234   234   218    k
204   171   235   235   219    l
205   172   236   236   220    m
206   173   237   237   221    n
207   174   238   238   222    o
208   175   239   239   223    p
210   224   240   240   224    r
211   225   241   241   225    s
212   226   242   242   226    t
213   227   243   243   227    u
198   228   244   244   228    f
200   229   245   245   229    kh
195   230   246   246   230    ts
222   231   247   247   231    ch
219   232   248   248   232    sh
221   233   249   249   233    sch
223   234   250   250   234    '       # hard sign
217   235   251   251   235    y
216   236   252   252   236    '       # soft sign
220   237   253   253   237    e       # reverse e
192   238   254   254   238    yu
209   239   255   223   239    ya
163   241   184   222   241    yo
177   243   180   182   211    g       # Ukrainian g with hook
164   245   186   185   244    ye      # Ukrainian ye
166   247   179   180   246    i       # Ukrainian i
167   249   191   187   247    yi      # Ukrainian yi
189   251   162   217   254    u       # Belorussian short u
190   252   185   220   240    N       # number sign
##################################################################
