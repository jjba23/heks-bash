# shellcheck shell=bash
# shellcheck disable=SC2155,SC2034,SC2207,SC2016
# =============================================================================
# Notes from the terminal — heks-bash (bash 4+)
#
# The basics of the Emacs notes setup (heks-emacs: notes.el and friends) for a
# shell, for when Emacs is not at hand.  It reads and writes the same plain
# files, in the same formats, so the two never disagree:
#
#   $NOTES_DIR/<topic>/<slug>.org     one Org file per note, topics are folders
#   $NOTES_DIR/todo.org               the inbox (`* Inbox' with `** TODO' items)
#   $NOTES_DIR/habits.org             TODOs with a `.+1w'-style repeater
#   $NOTES_DIR/contacts.org           contacts, details as properties
#   $NOTES_DIR/bookmarks.org          headings are categories, links bookmarks
#   <topic>/index.org                 generated between BEGIN/END markers
#
# Everything is one command, `n'.  fzf is used for the pickers when it is
# there; without it the prompts are plain.  Only coreutils, sed, awk and grep
# are required (rg is used when present).  Run `n help' for the list.
# Mirrors cask-and-cons/src/cask-and-cons/notes.zsh: change both together.
# =============================================================================

: "${NOTES_DIR:=$HOME/Hacking/private-notes}"

declare -A CC_NOTES_ACRONYMS=(
    [ah]=AH [ctms]=CTMS [boms]=BOMS [boap]=BOAP [ikea]=IKEA [vko]=VKO [p4]=P4
    [ai]=AI [sbt]=sbt [devops]=DevOps [nix]=Nix [guix]=Guix [sss]=SSS
    [adr]=ADR [http]=HTTP [apis]=APIs
)

__n_die () { printf 'n: %s\n' "$*" >&2; return 1; }

__n_root () { printf '%s' "${NOTES_DIR%/}"; }

__n_check () {
    [[ -d ${NOTES_DIR:-} ]] || { __n_die "no notes directory (NOTES_DIR=${NOTES_DIR:-unset})"; return 1; }
}

__n_tty () { __cc_has fzf && [[ -t 1 ]]; }

__n_trim () {
    local s=$1
    s=${s#"${s%%[![:space:]]*}"}
    s=${s%"${s##*[![:space:]]}"}
    printf '%s' "$s"
}

__n_slug () {
    local s=${1,,}
    s=$(printf '%s' "$s" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
    printf '%s\n' "${s:-untitled}"
}

# `http-apis' -> `HTTP APIs': the same titles the Emacs index pages carry.
__n_pretty () {
    local seg=${1#.} w out=() parts
    IFS=- read -r -a parts <<< "$seg"
    for w in "${parts[@]}"
    do
        if [[ -n ${CC_NOTES_ACRONYMS[$w]:-} ]]
        then
            out+=("${CC_NOTES_ACRONYMS[$w]}")
        elif [[ $w == @(and|of|for|the|to|in|a|on) ]]
        then
            out+=("$w")
        else
            out+=("${w^}")
        fi
    done
    local IFS=' '
    printf '%s\n' "${out[*]}"
}

__n_title () {
    local t f=$1
    t=$(sed -n -e 's/^#+[Tt][Ii][Tt][Ll][Ee]:[[:space:]]*//p' "$f" 2> /dev/null | head -n 1 | sed -e 's/[[:space:]]*$//')
    if [[ -z $t ]]
    then
        t=${f##*/}
        t=${t%.org}
    fi
    printf '%s\n' "$t"
}

__n_now () { LC_ALL=C date "$@"; }

__n_mtime () { stat -c %Y "$1" 2> /dev/null || stat -f %m "$1" 2> /dev/null; }

__n_clipboard () {
    if __cc_has pbpaste
    then
        pbpaste
    elif __cc_has wl-paste
    then
        wl-paste
    elif __cc_has xclip
    then
        xclip -o -selection clipboard
    fi
}

__n_copy () {
    if __cc_has pbcopy
    then
        printf '%s' "$1" | pbcopy
    elif __cc_has wl-copy
    then
        printf '%s' "$1" | wl-copy
    elif __cc_has xclip
    then
        printf '%s' "$1" | xclip -selection clipboard
    fi
}

__n_open_url () {
    if __cc_has xdg-open
    then
        xdg-open "$1" > /dev/null 2>&1
    elif __cc_has open
    then
        open "$1"
    else
        printf '%s\n' "$1"
    fi
}

# Open FILE (at LINE) in Emacs if a server answers, else in $VISUAL/$EDITOR.
__n_edit () {
    local f=$1 line=${2:-} ed
    if [[ -n ${NOTES_EDITOR:-} ]]
    then
        read -r -a ed <<< "$NOTES_EDITOR"
        "${ed[@]}" ${line:+"+$line"} "$f"
    elif __cc_has emacsclient && emacsclient -e t > /dev/null 2>&1
    then
        emacsclient -t ${line:+"+$line"} "$f"
    else
        read -r -a ed <<< "${VISUAL:-${EDITOR:-vi}}"
        "${ed[@]}" ${line:+"+$line"} "$f"
    fi
}

# ---- topics ----------------------------------------------------------------
__n_topics () {
    local root; root=$(__n_root)
    ( cd "$root" 2> /dev/null && find . -mindepth 1 -type d -not -path '*/.*' \
        -not -path './diary' -not -path './diary/*' | sed 's|^\./||' | LC_ALL=C sort )
}

# TAB-separated, newest first: topic, then "N notes · Nd — what its index says".
__n_topic_lines () {
    local root rel f mt now n days desc newest
    root=$(__n_root)
    now=$(date +%s)
    while IFS= read -r rel
    do
        [[ -n $rel ]] || continue
        n=0; mt=0; days=''; desc=''
        for f in "$root/$rel"/*.org
        do
            [[ -e $f && ${f##*/} != index.org ]] && n=$((n + 1))
        done
        newest=$(ls -t "$root/$rel"/*.org 2> /dev/null | head -n 1)
        if [[ -n $newest ]] && mt=$(__n_mtime "$newest") && [[ -n $mt ]]
        then
            days=" · $(( (now - mt) / 86400 ))d"
        else
            mt=0
        fi
        [[ -f $root/$rel/index.org ]] \
            && desc=$(sed -n '/^[^:#*[:space:]-]/{p;q;}' "$root/$rel/index.org" | cut -c1-60)
        printf '%s\t%s\t%s\n' "$mt" "$rel" "$n notes${days}${desc:+ — $desc}"
    done < <(__n_topics) | sort -rn | cut -f2-
}

# `Work Stuff/Infra' -> `work-stuff/infra'
__n_topic_name () {
    local s out='' segs
    IFS=/ read -r -a segs <<< "$1"
    for s in "${segs[@]}"
    do
        [[ -n $s ]] || continue
        out+=${out:+/}$(__n_slug "$s")
    done
    printf '%s\n' "$out"
}

# Ask where a note goes; sets REPLY.  A topic that does not exist is made.
__n_pick_topic () {
    local root topic='' out
    root=$(__n_root)
    if __n_tty
    then
        mapfile -t out < <(__n_topic_lines | fzf --print-query --expect=ctrl-n \
            --delimiter=$'\t' --with-nth=1,2 --tabstop=36 --height=60% --reverse \
            --prompt='Put the note in> ' \
            --header='enter: pick · ctrl-n: new topic from what you typed' \
            --preview="head -n 20 '$root'/{1}/index.org 2> /dev/null")
        if [[ ${out[1]:-} == ctrl-n || -z ${out[2]:-} ]]
        then
            topic=${out[0]:-}
        else
            topic=${out[2]%%$'\t'*}
        fi
    else
        __n_topics | sed 's/^/  /' >&2
        read -r -p "Put the note in (existing or new topic): " topic || return 1
    fi
    topic=$(__n_topic_name "$topic")
    [[ -n $topic ]] || { __n_die "a note needs a topic"; return 1; }
    if [[ ! -d $root/$topic ]]
    then
        local ans
        read -r -p "Create the new topic '$topic'? [y/N] " ans || return 1
        [[ $ans == [yY]* ]] || { __n_die cancelled; return 1; }
    fi
    REPLY=$topic
}

# ---- creating --------------------------------------------------------------
# __n_create TOPIC TITLE [TAGS] [BODY]  ->  prints the new file
__n_create () {
    local root topic=$1 title=$2 tags=${3:-} body=${4:-} dir slug file n=1
    root=$(__n_root)
    [[ -n $(__n_trim "$title") ]] || { __n_die "a note needs a title"; return 1; }
    slug=$(__n_slug "$title")
    dir=$root/$topic
    command mkdir -p -- "$dir"
    file=$dir/$slug.org
    while [[ -e $file ]]
    do
        n=$((n + 1))
        file=$dir/$slug-$n.org
    done
    {
        printf '#+title: %s\n' "$title"
        printf '#+date: %s\n' "$(__n_now '+[%Y-%m-%d %a]')"
        if [[ -n $tags ]]
        then
            local tl t
            tl=$(printf '%s' "$tags" | tr ',:' '  ')
            local -a ta
            read -r -a ta <<< "$tl"
            t=$(IFS=:; printf '%s' "${ta[*]}")
            printf '#+filetags: :%s:\n' "$t"
        fi
        printf '\n'
        [[ -n $body ]] && printf '%s\n' "$body"
    } > "$file"
    __n_index_up "$dir"
    printf '%s\n' "$file"
}

# n new [topic] [title]
__n_new () {
    __n_check || return 1
    local topic=${1:-} title=${2:-} file
    if [[ -z $topic ]]
    then
        __n_pick_topic || return 1
        topic=$REPLY
    else
        topic=$(__n_topic_name "$topic")
    fi
    [[ -n $title ]] || read -r -e -p 'Title: ' title
    file=$(__n_create "$topic" "$title") || return 1
    printf '%s\n' "${file#"$(__n_root)"/}"
    __n_edit "$file"
}

# n capture [-t topic] [-T title] [-g tags] [-c] [text...]   (or pipe text in)
__n_capture () {
    __n_check || return 1
    local topic='' title='' tags='' clip=0 text='' file
    while [[ ${1:-} == -* ]]
    do
        case $1 in
            -t) topic=$2; shift 2 ;;
            -T) title=$2; shift 2 ;;
            -g) tags=$2; shift 2 ;;
            -c) clip=1; shift ;;
            --) shift; break ;;
            *) __n_die "capture: unknown option $1"; return 2 ;;
        esac
    done
    if ((clip))
    then
        text=$(__n_clipboard)
    elif (($#))
    then
        text=$*
    elif [[ ! -t 0 ]]
    then
        text=$(cat)
    else
        read -r -e -p 'Note: ' text
    fi
    [[ -n $(__n_trim "$text") ]] || { __n_die "nothing to capture"; return 1; }
    if [[ -z $title ]]
    then
        title=${text%%$'\n'*}
        title=${title:0:60}
        read -r -e -i "$title" -p 'Title: ' title
    fi
    if [[ -z $topic ]]
    then
        __n_pick_topic || return 1
        topic=$REPLY
    else
        topic=$(__n_topic_name "$topic")
    fi
    local body=$text
    [[ $text == *$'\n'* ]] && body="#+begin_quote"$'\n'"$text"$'\n'"#+end_quote"
    file=$(__n_create "$topic" "$title" "$tags" "$body") || return 1
    printf 'captured in %s\n' "${file#"$(__n_root)"/}"
}

# ---- finding ---------------------------------------------------------------
__n_note_lines () {
    local root; root=$(__n_root)
    (
        cd "$root" || exit 1
        find . -name '*.org' -not -path './.*' -not -path './diary/*' -print0 \
            | xargs -0 grep -m1 -i '^#+title:' 2> /dev/null
    ) | sed -E 's|^\./([^:]*):#\+[Tt][Ii][Tt][Ll][Ee]:[[:space:]]*(.*)$|\2	\1|' | sort -f
}

# n find [query]
__n_find () {
    __n_check || return 1
    local root sel
    root=$(__n_root)
    if __n_tty
    then
        sel=$(__n_note_lines | fzf --query="${*:-}" --delimiter=$'\t' --with-nth=1,2 \
            --tabstop=48 --height=70% --reverse --prompt='Note> ' \
            --preview="head -n 40 '$root'/{2}") || return 0
    else
        sel=$(__n_note_lines | grep -i -- "${*:-.}" | head -n 1)
    fi
    [[ -n $sel ]] || { __n_die "no note found"; return 1; }
    __n_edit "$root/${sel#*$'\t'}"
}

# n search pattern
__n_search () {
    __n_check || return 1
    local root sel hits
    root=$(__n_root)
    (($#)) || { __n_die "usage: n search <pattern>"; return 2; }
    if __cc_has rg
    then
        hits=$(rg --line-number --no-heading --color=never --glob '*.org' -- "$*" "$root" 2> /dev/null)
    else
        hits=$(grep -rn --include='*.org' --exclude-dir='.*' -- "$*" "$root" 2> /dev/null)
    fi
    [[ -n $hits ]] || { __n_die "nothing matches '$*'"; return 1; }
    hits=${hits//"$root/"/}
    if __n_tty
    then
        sel=$(printf '%s\n' "$hits" | fzf --delimiter=: --height=70% --reverse --prompt='Search> ') || return 0
        local f=${sel%%:*} rest=${sel#*:}
        __n_edit "$root/$f" "${rest%%:*}"
    else
        printf '%s\n' "$hits"
    fi
}

# n cd [topic]
__n_cd () {
    __n_check || return 1
    local root; root=$(__n_root)
    if [[ -n ${1:-} && -d $root/$1 ]]
    then
        cd "$root/$1" || return 1
    elif __n_tty
    then
        local sel
        sel=$(__n_topic_lines | fzf --delimiter=$'\t' --with-nth=1,2 --tabstop=36 \
            --height=60% --reverse --prompt='cd> ' --query="${*:-}") || return 0
        cd "$root/${sel%%$'\t'*}" || return 1
    else
        cd "$root" || return 1
    fi
}

# ---- todos & habits --------------------------------------------------------
# n todo "text"  -- into the Inbox of todo.org, the way Emacs captures it
__n_todo_add () {
    __n_check || return 1
    local text="$*" file
    file=$(__n_root)/todo.org
    [[ -n $text ]] || read -r -e -p 'Todo: ' text
    [[ -n $(__n_trim "$text") ]] || { __n_die "nothing to add"; return 1; }
    [[ -f $file ]] || printf '#+title: Todo\n\n* Inbox\n' > "$file"
    local entry="** TODO ${text}"$'\n'":PROPERTIES:"$'\n'":CREATED: $(__n_now '+[%Y-%m-%d %a %H:%M]')"$'\n'":END:"$'\n'
    ENTRY=$entry awk '
        function put() { printf "%s", ENVIRON["ENTRY"]; printf "%s", blanks; blanks = ""; done = 1 }
        {
            if (inb) {
                if ($0 ~ /^\* /) { put(); inb = 0; print; next }
                if ($0 ~ /^[ \t]*$/) { blanks = blanks $0 "\n"; next }
                printf "%s", blanks; blanks = ""; print; next
            }
            if ($0 ~ /^\* Inbox[ \t]*$/) inb = 1
            print
        }
        END { if (inb) put(); if (!done) { print "* Inbox"; printf "%s", ENVIRON["ENTRY"] } }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    printf 'added to the inbox: %s\n' "$text"
}

# n todos -- every open TODO/WIP/REVIEWING in the notes; pick one to open it
__n_todos () {
    __n_check || return 1
    local root hits
    root=$(__n_root)
    if __cc_has rg
    then
        hits=$(rg --line-number --no-heading --color=never --glob '*.org' \
            '^\*+ (TODO|WIP|REVIEWING) ' "$root" 2> /dev/null)
    else
        hits=$(grep -rnE --include='*.org' --exclude-dir='.*' '^\*+ (TODO|WIP|REVIEWING) ' "$root" 2> /dev/null)
    fi
    [[ -n $hits ]] || { echo "no open todos"; return 0; }
    hits=${hits//"$root/"/}
    if __n_tty
    then
        local sel
        sel=$(printf '%s\n' "$hits" | fzf --delimiter=: --height=70% --reverse --prompt='Todo> ') || return 0
        local f=${sel%%:*} rest=${sel#*:}
        __n_edit "$root/$f" "${rest%%:*}"
    else
        printf '%s\n' "$hits"
    fi
}

# Days since a fixed epoch for a civil date (pure arithmetic: no GNU/BSD date).
__n_daynum () {
    local y=$((10#$1)) m=$((10#$2)) d=$((10#$3)) era yoe doy doe
    ((m <= 2)) && y=$((y - 1))
    era=$(( (y >= 0 ? y : y - 399) / 400 ))
    yoe=$((y - era * 400))
    doy=$(( (153 * ((m + 9) % 12) + 2) / 5 + d - 1 ))
    doe=$((yoe * 365 + yoe / 4 - yoe / 100 + doy))
    printf '%s' $((era * 146097 + doe))
}

__n_leap () { local y=$1; ((y % 4 == 0 && (y % 100 != 0 || y % 400 == 0))); }

# Birthdays within N days (default 30), from the :BIRTHDAY: properties.
__n_birthdays () {
    __n_check || return 1
    local days=${1:-30} file
    file=$(__n_root)/contacts.org
    [[ -f $file ]] || { __n_die "no contacts.org"; return 1; }
    local ty tm td t0 name b y m d t diff age
    read -r ty tm td < <(date '+%Y %m %d')
    t0=$(__n_daynum "$ty" "$tm" "$td")
    local -a rows=()
    local re='^((([0-9]{4})-)|--)?([0-9]{2})-([0-9]{2})$'
    while IFS=$'\t' read -r name b
    do
        [[ $b =~ $re ]] || continue
        y=${BASH_REMATCH[3]}; m=${BASH_REMATCH[4]}; d=${BASH_REMATCH[5]}
        local yy=$ty
        d=$((10#$d))
        if ((10#$m == 2 && d == 29)) && ! __n_leap "$yy"; then d=28; fi
        t=$(__n_daynum "$yy" "$m" "$d")
        if ((t < t0))
        then
            yy=$((ty + 1)); d=$((10#${BASH_REMATCH[5]}))
            if ((10#$m == 2 && d == 29)) && ! __n_leap "$yy"; then d=28; fi
            t=$(__n_daynum "$yy" "$m" "$d")
        fi
        diff=$((t - t0))
        ((diff <= days)) || continue
        age=''
        [[ -n $y ]] && age=" ($((yy - 10#$y)))"
        rows+=("$(printf '%05d' "$diff")"$'\t'"$diff"$'\t'"🎂 $name$age"$'\t'"$m-$(printf '%02d' "$d")")
    done < <(awk '/^\* /{name=substr($0,3)} /^:BIRTHDAY:/{b=$2; print name "\t" b}' "$file")
    ((${#rows[@]})) || { echo "no birthdays in the next $days days"; return 0; }
    local r f1 f2 f3 f4
    while IFS=$'\t' read -r _ f2 f3 f4
    do
        if ((f2 == 0))
        then
            printf '  %-9s %s\n' today "$f3"
        elif ((f2 == 1))
        then
            printf '  %-9s %s\n' tomorrow "$f3"
        else
            printf '  in %-6s %s  %s\n' "${f2}d" "$f3" "$f4"
        fi
    done < <(printf '%s\n' "${rows[@]}" | LC_ALL=C sort)
}

# Habits whose next date is today or past, from habits.org.
__n_habits_due () {
    local file; file=$(__n_root)/habits.org
    [[ -f $file ]] || return 0
    awk -v today="$(__n_now +%F)" '
        /^\*+ TODO/ { t = $0; sub(/^\*+ TODO +/, "", t); next }
        /SCHEDULED: </ && t != "" {
            match($0, /<[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)
            d = substr($0, RSTART + 1, 10)
            if (d <= today) print "  ◌ " t "  (" d ")"
            t = ""
        }' "$file"
}

# n today -- birthdays, habits due, the inbox
__n_today () {
    __n_check || return 1
    local b h i
    b=$(__n_birthdays 7 2> /dev/null)
    h=$(__n_habits_due)
    i=$(awk '/^\* Inbox/{inb=1; next} /^\* /{inb=0} inb && /^\*+ TODO/{sub(/^\*+ TODO +/,""); print "  ☐ " $0}' "$(__n_root)/todo.org" 2> /dev/null)
    printf '%s%stoday%s %s\n' "${CC_BOLD_OUT:-}" "${CC_ACCENT_OUT:-}" "${CC_RESET_OUT:-}" "$(__n_now '+%a %d %b')"
    [[ -n $b && $b != "no birthdays"* ]] && { printf '\nBirthdays\n%s\n' "$b"; }
    [[ -n $h ]] && { printf '\nHabits due\n%s\n' "$h"; }
    [[ -n $i ]] && { printf '\nInbox\n%s\n' "$i"; }
    [[ -z $h && -z $i && ( -z $b || $b == "no birthdays"* ) ]] && printf '\nnothing pending.\n'
    return 0
}

# ---- contacts --------------------------------------------------------------
__n_contact_lines () {
    awk '
        function flush() { if (name != "") print name "\t" email "\t" phone "\t" bd }
        /^\* / { flush(); name = substr($0, 3); email = phone = bd = ""; next }
        /^:EMAIL:/ { sub(/^:EMAIL:[ \t]*/, ""); email = $0 }
        /^:PHONE:/ { sub(/^:PHONE:[ \t]*/, ""); phone = $0 }
        /^:BIRTHDAY:/ { sub(/^:BIRTHDAY:[ \t]*/, ""); bd = $0 }
        END { flush() }' "$(__n_root)/contacts.org"
}

# n contact [query] -- pick one; prints Name <email> and copies it
__n_contact () {
    __n_check || return 1
    [[ -f $(__n_root)/contacts.org ]] || { __n_die "no contacts.org"; return 1; }
    local sel
    if __n_tty
    then
        sel=$(__n_contact_lines | fzf --query="${*:-}" --delimiter=$'\t' --tabstop=28 \
            --height=50% --reverse --prompt='Contact> ') || return 0
    else
        __n_contact_lines | grep -i -- "${*:-.}"
        return 0
    fi
    local f1 f2 f3 f4 out
    IFS=$'\t' read -r f1 f2 f3 f4 <<< "$sel"
    out=$f1
    [[ -n $f2 ]] && out="$f1 <$f2>"
    printf '%s\n' "$out"
    [[ -n $f3 ]] && printf '  %s\n' "$f3"
    __n_copy "${f2:-$f1}"
}

# n contact add NAME [EMAIL] [PHONE] [BIRTHDAY]
__n_contact_add () {
    __n_check || return 1
    local file name=${1:-} email=${2:-} phone=${3:-} bd=${4:-}
    file=$(__n_root)/contacts.org
    [[ -n $name ]] || read -r -e -p 'Name: ' name
    [[ -n $name ]] || { __n_die "a contact needs a name"; return 1; }
    local re='^((([0-9]{4})-)|--)?[0-9]{2}-[0-9]{2}$'
    if [[ -n $bd && ! $bd =~ $re ]]
    then
        __n_die "a birthday is YYYY-MM-DD or MM-DD, not '$bd'"
        return 1
    fi
    [[ -f $file ]] || printf '#+title: Contacts\n\n' > "$file"
    [[ -z $(tail -c1 "$file") ]] || printf '\n' >> "$file"
    {
        printf '* %s\n' "$name"
        if [[ -n $email$phone$bd ]]
        then
            printf ':PROPERTIES:\n'
            [[ -n $email ]] && printf ':EMAIL: %s\n' "$email"
            [[ -n $phone ]] && printf ':PHONE: %s\n' "$phone"
            [[ -n $bd ]] && printf ':BIRTHDAY: %s\n' "$bd"
            printf ':END:\n'
        fi
    } >> "$file"
    printf 'added %s\n' "$name"
}

# ---- bookmarks -------------------------------------------------------------
# title <TAB> category <TAB> url, one per link
__n_bookmark_lines () {
    awk '
        /^\*+ / { match($0, /^\*+/); lvl = RLENGTH; t = substr($0, lvl + 2); sub(/ +$/, "", t)
                  st[lvl] = t; for (k = lvl + 1; k <= mx; k++) delete st[k]; mx = lvl; next }
        {
            s = $0
            while (match(s, /\[\[https?:\/\/[^]]+\](\[[^]]*\])?\]/)) {
                l = substr(s, RSTART + 2, RLENGTH - 3); s = substr(s, RSTART + RLENGTH)
                url = l; title = ""
                if (i = index(l, "][")) { url = substr(l, 1, i - 1); title = substr(l, i + 2) }
                cat = ""
                for (k = 1; k <= mx; k++) cat = cat (k > 1 ? " / " : "") st[k]
                print (title == "" ? url : title) "\t" cat "\t" url
            }
        }' "$(__n_root)/bookmarks.org"
}

# n bookmark [query]  -> open
__n_bookmark_open () {
    __n_check || return 1
    [[ -f $(__n_root)/bookmarks.org ]] || { __n_die "no bookmarks.org"; return 1; }
    local sel
    if __n_tty
    then
        sel=$(__n_bookmark_lines | fzf --query="${*:-}" --delimiter=$'\t' --with-nth=1,2 \
            --tabstop=60 --height=70% --reverse --prompt='Bookmark> ') || return 0
    else
        sel=$(__n_bookmark_lines | grep -i -- "${*:-.}" | head -n 1)
    fi
    [[ -n $sel ]] || return 1
    __n_open_url "${sel##*$'\t'}"
}

# n bookmark add URL [title] [category]
__n_bookmark_add () {
    __n_check || return 1
    local file url=${1:-} title=${2:-} cat=${3:-}
    file=$(__n_root)/bookmarks.org
    [[ -f $file ]] || { __n_die "no bookmarks.org"; return 1; }
    if [[ -z $url ]]
    then
        local clip; clip=$(__n_clipboard)
        [[ $clip == http*://* ]] && url=$clip
        read -r -e -i "$url" -p 'URL: ' url
    fi
    [[ $url == http*://* ]] || { __n_die "that is not a URL: $url"; return 1; }
    if grep -qF -- "[[$url]" "$file"
    then
        echo "already bookmarked: $(__n_bookmark_lines | awk -F'\t' -v u="$url" '$3==u{print $2; exit}')"
        return 0
    fi
    if [[ -z $title ]]
    then
        title=$(curl -sL --max-time 4 -- "$url" 2> /dev/null \
            | sed -n 's/.*<[Tt][Ii][Tt][Ll][Ee][^>]*>\(.*\)<\/[Tt][Ii][Tt][Ll][Ee]>.*/\1/p' | head -n 1)
        read -r -e -i "$title" -p 'Title: ' title
    fi
    [[ -n $title ]] || title=$url
    if [[ -z $cat ]]
    then
        local cats
        cats=$(awk '/^\*+ /{match($0,/^\*+/); l=RLENGTH; t=substr($0,l+2); sub(/ +$/,"",t); st[l]=t; for(k=l+1;k<=m;k++)delete st[k]; m=l; p=""; for(k=1;k<=l;k++)p=p (k>1?" / ":"") st[k]; print p}' "$file")
        if __n_tty
        then
            local out
            mapfile -t out < <(printf '%s\n' "$cats" | fzf --print-query --expect=ctrl-n --height=50% --reverse \
                --prompt='Category> ' --header='enter: pick · ctrl-n: new category from what you typed')
            if [[ ${out[1]:-} == ctrl-n || -z ${out[2]:-} ]]
            then
                cat=${out[0]:-}
            else
                cat=${out[2]}
            fi
        else
            printf '%s\n' "$cats" >&2
            read -r -p "Category: " cat
        fi
    fi
    [[ -n $cat ]] || { __n_die "a bookmark needs a category"; return 1; }
    local item="- [[${url}][${title}]]"
    ITEM=$item TARGET=$cat awk '
        function put() { printf "%s\n", ENVIRON["ITEM"]; printf "%s", blanks; blanks = ""; done = 1 }
        BEGIN { n = split(ENVIRON["TARGET"], T, " / ") }
        {
            if ($0 ~ /^\*+ /) {
                if (inb) { put(); inb = 0 }
                match($0, /^\*+/); lvl = RLENGTH; t = substr($0, lvl + 2); sub(/ +$/, "", t)
                st[lvl] = t; for (k = lvl + 1; k <= mx; k++) delete st[k]; mx = lvl
                if (!done && lvl == n) { ok = 1; for (k = 1; k <= n; k++) if (st[k] != T[k]) ok = 0; if (ok) inb = 1 }
                print; next
            }
            if (inb) {
                if ($0 ~ /^[ \t]*$/) { blanks = blanks $0 "\n"; next }
                printf "%s", blanks; blanks = ""; print; next
            }
            print
        }
        END {
            if (inb) put()
            if (!done) {
                for (k = 1; k <= n; k++) { s = ""; for (j = 0; j < k; j++) s = s "*"; print s " " T[k] }
                printf "%s\n", ENVIRON["ITEM"]
            }
        }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    printf 'bookmarked under %s\n' "$cat"
}

__n_bookmark () {
    case ${1:-} in
        add) shift; __n_bookmark_add "$@" ;;
        *) __n_bookmark_open "$@" ;;
    esac
}

# ---- index pages -----------------------------------------------------------
__n_index_dir_ok () {
    local root dir=${1%/} rel
    root=$(__n_root)
    [[ $dir == "$root" || $dir == "$root"/* ]] || return 1
    rel=${dir#"$root"}; rel=${rel#/}
    [[ -z $rel || $rel == .archive ]] && return 0
    [[ $rel == @(.git|.metals)?(/*) ]] && return 1
    [[ $rel == diary?(/*) ]] && return 1
    rel=${rel#.archive/}
    [[ $rel == @(.*|*/.*) ]] && return 1
    return 0
}

# Rebuild the generated part of DIR/index.org (an index without the markers is
# somebody's own page and is left alone).  Same format as notes.el writes.
# Sets REPLY=written when the file changed.
__n_index_update () {
    local root dir=${1%/}
    root=$(__n_root)
    __n_index_dir_ok "$dir" || return 0
    local file=$dir/index.org old=''
    [[ -f $file ]] && old=$(< "$file")
    if [[ -n $old && $old != *'# BEGIN GENERATED INDEX'* && $old != *'# This index is generated'* ]]
    then
        return 0
    fi
    local -a subs=() notes=()
    local d f
    for d in "$dir"/*/
    do
        d=${d%/}
        [[ -d $d ]] || continue
        [[ ${d##*/} == diary ]] && continue
        __n_index_dir_ok "$d" || continue
        [[ -n $(find "$d" -name '*.org' -print -quit 2> /dev/null) ]] || continue
        [[ -f $d/index.org ]] || __n_index_update "$d"
        [[ -f $d/index.org ]] || continue
        subs+=("$(__n_pretty "${d##*/}")"$'\t'"./${d##*/}/index.org")
    done
    if [[ $dir != "$root" ]]
    then
        for f in "$dir"/*.org
        do
            [[ -f $f && ${f##*/} == index.org ]] && continue
            [[ -f $f ]] || continue
            notes+=("$(__n_title "$f")"$'\t'"./${f##*/}")
        done
    fi
    # code-point order, as Emacs sorts the titles (an emoji sorts after letters)
    local sorted
    if ((${#subs[@]}))
    then
        sorted=$(printf '%s\n' "${subs[@]}" | LC_ALL=C sort -f); mapfile -t subs <<< "$sorted"
    fi
    if ((${#notes[@]}))
    then
        sorted=$(printf '%s\n' "${notes[@]}" | LC_ALL=C sort -f); mapfile -t notes <<< "$sorted"
    fi
    local body='' e
    if ((${#subs[@]}))
    then
        body+="* Topics"$'\n'
        for e in "${subs[@]}"
        do
            body+="- [[file:${e#*$'\t'}][${e%%$'\t'*}]]"$'\n'
        done
    fi
    if ((${#notes[@]}))
    then
        body+="* Notes"$'\n'
        for e in "${notes[@]}"
        do
            body+="- [[file:${e#*$'\t'}][${e%%$'\t'*}]]"$'\n'
        done
    fi
    [[ -z $body && $dir != "$root" ]] && return 0

    local head='' desc='' tail=''
    local -a L=()
    local i=0 j n idx k m
    if [[ -n $old ]]
    then
        mapfile -t L <<< "$old"
        n=${#L[@]}
        if [[ ${L[0]} == ':PROPERTIES:' ]]
        then
            while ((i < n)) && [[ ${L[i]} != ':END:' ]]; do i=$((i + 1)); done
            i=$((i + 1))
        fi
        local start=$i
        while ((i < n)) && [[ ${L[i]} == '#+'* ]]; do i=$((i + 1)); done
        if ((i > start))
        then
            head=$(printf '%s\n' "${L[@]:start:i-start}")
        fi
    fi
    if [[ -z $head ]]
    then
        local rel=${dir#"$root"} title
        rel=${rel#/}
        if [[ -z $rel ]]
        then
            title=Notes
        else
            local -a segs parts=()
            IFS=/ read -r -a segs <<< "$rel"
            local s
            for s in "${segs[@]}"; do parts+=("$(__n_pretty "$s")"); done
            title=$(IFS='|'; printf '%s' "${parts[*]}")
            title=${title//|/ / }
        fi
        head="#+title: $title"$'\n'"#+date: $(__n_now '+[%Y-%m-%d %a]')"
    else
        j=$i
        while ((j < n)) && [[ ${L[j]} != '*'* && ${L[j]} != '# BEGIN GENERATED INDEX' && ${L[j]} != '# This index'* ]]
        do
            j=$((j + 1))
        done
        if ((j > i)); then desc=$(printf '%s\n' "${L[@]:i:j-i}"); fi
        desc=$(__n_trim "$desc")
        k=-1; m=-1
        for ((idx = i; idx < n; idx++))
        do
            if [[ ${L[idx]} == '# END GENERATED INDEX' ]]; then k=$idx; break; fi
        done
        if ((k >= 0))
        then
            if ((k + 1 < n)); then tail=$(printf '%s\n' "${L[@]:k+1}"); fi
        else
            for ((idx = i; idx < n; idx++))
            do
                if [[ ${L[idx]} == '* Not indexed here' ]]; then m=$idx; break; fi
            done
            if ((m >= 0))
            then
                local e2=$((n - 1))
                for ((idx = m; idx < n; idx++))
                do
                    if [[ ${L[idx]} == '# This index'* ]]; then e2=$((idx - 1)); break; fi
                done
                tail=$(printf '%s\n' "${L[@]:m:e2-m+1}")
            fi
        fi
        tail=$(__n_trim "$tail")
    fi
    local out="$head"$'\n\n'
    [[ -n $desc ]] && out+="$desc"$'\n\n'
    out+="# BEGIN GENERATED INDEX"$'\n'"$body# END GENERATED INDEX"$'\n'
    [[ -n $tail ]] && out+=$'\n'"$tail"$'\n'
    command mkdir -p -- "$dir"
    printf '%s' "$out" > "$file.tmp"
    if [[ -f $file ]] && cmp -s "$file.tmp" "$file"
    then
        rm -f -- "$file.tmp"
        return 0
    fi
    mv -- "$file.tmp" "$file"
    REPLY=written
}

# The index of DIR and of every folder above it, up to the notes root.
__n_index_up () {
    local root d=${1%/}
    root=$(__n_root)
    while [[ $d == "$root" || $d == "$root"/* ]]
    do
        __n_index_update "$d"
        [[ $d == "$root" ]] && break
        d=${d%/*}
    done
}

# n index -- every index page, children first
__n_index_all () {
    __n_check || return 1
    local root d count=0
    root=$(__n_root)
    local -a dirs
    # deepest first
    mapfile -t dirs < <(
        { find "$root" -mindepth 1 -type d -not -path "$root/.*" -not -path "$root/diary" -not -path "$root/diary/*"
          [[ -d $root/.archive ]] && find "$root/.archive" -type d; } \
        | awk -F/ '{ print NF " " $0 }' | sort -rn | cut -d' ' -f2-)
    for d in "${dirs[@]}" "$root"
    do
        REPLY=''
        __n_index_update "$d"
        [[ $REPLY == written ]] && count=$((count + 1))
    done
    printf 'indexes: %d written\n' "$count"
}

# ---- the command -----------------------------------------------------------
n () {
    local cmd=${1:-help}
    (($#)) && shift
    case $cmd in
        c | capture) __n_capture "$@" ;;
        new) __n_new "$@" ;;
        f | find | open) __n_find "$@" ;;
        s | search | grep) __n_search "$@" ;;
        x | todo | add) __n_todo_add "$@" ;;
        t | todos) __n_todos "$@" ;;
        d | today) __n_today ;;
        b | bookmark | bm) __n_bookmark "$@" ;;
        k | contact) if [[ ${1:-} == add ]]; then shift; __n_contact_add "$@"; else __n_contact "$@"; fi ;;
        u | birthdays) __n_birthdays "$@" ;;
        i | index) __n_index_all ;;
        cd) __n_cd "$@" ;;
        dir) printf '%s\n' "$(__n_root)" ;;
        h | help | -h | --help)
            cat << 'EOF'
n — notes from the terminal (same files as Emacs)

  n capture [-t topic] [-T title] [-g tags] [-c] [text]
                            file text (args, a pipe, or -c the clipboard) as a note;
                            asks where it goes, with completion when fzf is there
  n new [topic] [title]     write a new note in $EDITOR (Emacs if a server runs)
  n find [query]            pick a note by title and open it
  n search <pattern>        search the text of every note
  n todo <text>             add a TODO to the inbox (todo.org)
  n todos                   every open TODO in the notes; pick one to open it
  n today                   birthdays this week, habits due, the inbox
  n bookmark [query]        pick a bookmark and open it
  n bookmark add [url [title [category]]]
                            file a URL (default: the clipboard) under a category
  n contact [query]         pick a contact; prints and copies the address
  n contact add <name> [email] [phone] [birthday]
  n birthdays [days]        birthdays coming up (default 30 days)
  n index                   regenerate every topic's index.org
  n cd [topic]              cd into a topic folder
  n dir                     print the notes directory ($NOTES_DIR)
EOF
            ;;
        *)
            printf "n: unknown command '%s' (try: n help)\n" "$cmd" >&2
            return 2
            ;;
    esac
}

alias nc='n capture'
alias nf='n find'
alias nx='n todo'
alias nt='n today'

_n_complete () {
    local cur=${COMP_WORDS[COMP_CWORD]}
    if ((COMP_CWORD == 1))
    then
        mapfile -t COMPREPLY < <(compgen -W 'capture new find search todo todos today bookmark contact birthdays index cd dir help' -- "$cur")
    elif [[ ${COMP_WORDS[1]} == @(cd|capture|c|new) ]] && ((COMP_CWORD == 2))
    then
        mapfile -t COMPREPLY < <(compgen -W "$(__n_topics)" -- "$cur")
    fi
}
complete -F _n_complete n
