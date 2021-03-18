#!/bin/sh

if [ -n "$nocolor" ] && [ "$nocolor" = "nocolor" ]; then
  bldred=''
  bldgrn=''
  bldblu=''
  bldylw=''
  txtrst=''
else
  bldred='\033[1;31m' # Bold Red
  bldgrn='\033[1;32m' # Bold Green
  bldblu='\033[1;34m' # Bold Blue
  bldylw='\033[1;33m' # Bold Yellow
  txtrst='\033[0m'
fi

logit () {
  printf "%b\n" "$1" | tee -a "$logger"
}

info () {
  local infoCountCheck
  while getopts c args
  do
    case $args in
    c) infoCountCheck="true" ;;
    *) exit 1 ;;
    esac
  done
  if [ "$infoCountCheck" = "true" ]; then
    printf "%b\n" "${bldblu}[INFO]${txtrst} $2" | tee -a "$logger"
    totalChecks=$((totalChecks + 1))
  else
    printf "%b\n" "${bldblu}[INFO]${txtrst} $1" | tee -a "$logger"
  fi
}

pass () {
  local passScored
  while getopts sc args
  do
    case $args in
    s) passScored="true" ;;
    c) passCountCheck="true" ;;
    *) exit 1 ;;
    esac
  done
  if [ "$passScored" = "true" ]; then
    printf "%b\n" "${bldgrn}[PASS]${txtrst} $2" | tee -a "$logger"
    totalChecks=$((totalChecks + 1))
    currentScore=$((currentScore + 1))
  elif [ "$passCountCheck" = "true" ]; then
    printf "%b\n" "${bldgrn}[PASS]${txtrst} $2" | tee -a "$logger"
    totalChecks=$((totalChecks + 1))
  else
    printf "%b\n" "${bldgrn}[PASS]${txtrst} $1" | tee -a "$logger"
  fi
}

warn () {
  local warnScored
  while getopts s args
  do
    case $args in
    s) warnScored="true" ;;
    *) exit 1 ;;
    esac
  done
  if [ "$warnScored" = "true" ]; then
    printf "%b\n" "${bldred}[WARN]${txtrst} $2" | tee -a "$logger"
    totalChecks=$((totalChecks + 1))
    currentScore=$((currentScore - 1))
  else
    printf "%b\n" "${bldred}[WARN]${txtrst} $1" | tee -a "$logger"
  fi
}

note () {
  local noteCountCheck
  while getopts c args
  do
    case $args in
    c) noteCountCheck="true" ;;
    *) exit 1 ;;
    esac
  done
  if [ "$noteCountCheck" = "true" ]; then
    printf "%b\n" "${bldylw}[NOTE]${txtrst} $2" | tee -a "$logger"
    totalChecks=$((totalChecks + 1))
  else
    printf "%b\n" "${bldylw}[NOTE]${txtrst} $1" | tee -a "$logger"
  fi
}

yell () {
  printf "%b\n" "${bldylw}$1${txtrst}\n"
}

appendjson () {
  if [ -s "$logger.json" ]; then
    tail -n 1 "$logger.json" | wc -c | xargs -I {} truncate "$logger.json" -s -{}
    printf "},\n" | tee -a "$logger.json" 2>/dev/null 1>&2
  else
    printf "[" | tee -a "$logger.json" 2>/dev/null 1>&2
  fi
}

beginjson () {
  printf "{\n  \"dockerbenchsecurity\": \"%s\",\n  \"start\": %s,\n  \"tests\": [" "$1" "$2" | tee -a "$logger.json" 2>/dev/null 1>&2
}

endjson (){
  printf "\n  ], \"checks\": %s, \"score\": %s, \"end\": %s\n}]" "$1" "$2" "$3" | tee -a "$logger.json" 2>/dev/null 1>&2
}

logjson (){
  printf "\n  \"%s\": \"%s\"," "$1" "$2" | tee -a "$logger.json" 2>/dev/null 1>&2
}

SSEP=
SEP=
startsectionjson() {
  printf "%s\n    {\"id\": \"%s\", \"desc\": \"%s\",  \"results\": [" "$SSEP" "$1" "$2" | tee -a "$logger.json" 2>/dev/null 1>&2
  SEP=
  SSEP=","
}

endsectionjson() {
  printf "\n    ]}" | tee -a "$logger.json" 2>/dev/null 1>&2
}

starttestjson() {
  printf "%s\n      {\"id\": \"%s\", \"desc\": \"%s\", " "$SEP" "$1" "$2" | tee -a "$logger.json" 2>/dev/null 1>&2
  SEP=","
}

logcheckresult() {
  # Log to JSON
  if [ $# -eq 1 ]; then
      printf "\"result\": \"%s\"" "$1" | tee -a "$logger.json" 2>/dev/null 1>&2
  elif [ $# -eq 2 ]; then
      # Result also contains details
      printf "\"result\": \"%s\", \"details\": \"%s\"" "$1" "$2" | tee -a "$logger.json" 2>/dev/null 1>&2
  else
      # Result also includes details and a list of items. Add that directly to details and to an array property "items"
      # Also limit the number of items to $limit, if $limit is non-zero
      if [ $limit != 0 ]; then
        truncItems=""
        ITEM_COUNT=0
        for item in $3; do
          truncItems="$truncItems $item"
          ITEM_COUNT=$((ITEM_COUNT + 1));
          if [ "$ITEM_COUNT" == "$limit" ]; then
            truncItems="$truncItems (truncated)"
            break;
          fi
        done
      else
        truncItems=$3
      fi
      itemsJson=$(printf "["; ISEP=""; ITEMCOUNT=0; for item in $truncItems; do printf "%s\"%s\"" "$ISEP" "$item"; ISEP=","; done; printf "]")
      printf "\"result\": \"%s\", \"details\": \"%s: %s\", \"items\": %s" "$1" "$2" "$truncItems" "$itemsJson" | tee -a "$logger.json" 2>/dev/null 1>&2
  fi

  # Log remediation measure to JSON
  if [ -n "$remediation" ] && [ "$1" != "PASS" ]; then
    printf ", \"remediation\": \"%s\"" "$remediation" | tee -a "$logger.json" 2>/dev/null 1>&2
    if [ -n "$remediationImpact" ]; then
      printf ", \"remediation-impact\": \"%s\"" "$remediationImpact" | tee -a "$logger.json" 2>/dev/null 1>&2
    fi
  fi
  printf "}" | tee -a "$logger.json" 2>/dev/null 1>&2

  # Save remediation measure for print log to stdout
  if [ -n "$remediation" ] && [ "$1" != "PASS" ]; then
    if [ -n "${checkHeader}" ]; then
      if [ -n "${addSpaceHeader}" ]; then
        globalRemediation="${globalRemediation}\n"
      fi
      globalRemediation="${globalRemediation}\n${bldblu}[INFO]${txtrst} ${checkHeader}"
      checkHeader=""
      addSpaceHeader="1"
    fi
    globalRemediation="${globalRemediation}\n${bldblu}[INFO]${txtrst} ${id} - ${remediation}"
    if [ -n "${remediationImpact}" ]; then
      globalRemediation="${globalRemediation} Impact: ${remediationImpact}"
    fi
  fi
}