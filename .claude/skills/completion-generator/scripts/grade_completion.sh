#!/bin/zsh
# Grader script for completion-generator skill
# Usage: ./grade_completion.sh <completion_file_path> <eval_name>

COMPLETION_FILE=$1
EVAL_NAME=$2

if [[ ! -f "$COMPLETION_FILE" ]]; then
  echo '{"expectations":[],"summary":{"passed":0,"failed":1,"total":1,"pass_rate":0},"error":"File not found"}'
  exit 1
fi

CONTENT=$(cat "$COMPLETION_FILE")
RESULTS="[]"
PASSED=0
FAILED=0
TOTAL=0

# Helper: check if content matches a pattern
check() {
  local name="$1"
  local pattern="$2"
  local desc="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$CONTENT" | grep -Eq "$pattern"; then
    PASSED=$((PASSED + 1))
    RESULTS=$(echo "$RESULTS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
data.append({'text': '$desc', 'passed': True, 'evidence': 'Found: $name'})
print(json.dumps(data))
")
  else
    FAILED=$((FAILED + 1))
    RESULTS=$(echo "$RESULTS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
data.append({'text': '$desc', 'passed': False, 'evidence': 'Not found: $name'})
print(json.dumps(data))
")
  fi
}

case "$EVAL_NAME" in
  jq)
    check "compdef" "^#compdef jq" "The file starts with #compdef jq"
    check "license" "Copyright" "The file has copyright/license header"
    check "function" "^_jq\\(\\)" "The file defines a _jq() function"
    check "endcall" '_jq "\$@"' "The file calls _jq \"\$@\" at the end"
    check "arguments" "_arguments" "The file uses _arguments"
    check "help" "help" "Option --help is defined"
    check "version" "version" "Option --version is defined"
    check "raw-output" "raw-output" "Option --raw-output is defined"
    check "from-file" "from-file" "Option --from-file is defined"
    check "arg" "\-\-arg" "Option --arg is defined"
    check "slurp" "\-\-slurp" "Option --slurp is defined"
    check "compact" "compact-output" "Option --compact-output is defined"
    check "color" "color-output" "Option --color-output is defined"
    check "monochrome" "monochrome-output" "Option --monochrome-output is defined"
    check "identity" "jq filter" "Positional argument jq filter is defined"
    check "files" "input files:_files" "Positional argument input files is defined"
    ;;

  bat)
    check "compdef" "^#compdef bat" "The file starts with #compdef bat"
    check "license" "Copyright" "The file has copyright/license header"
    check "function" "^_bat\\(\\)" "The file defines a _bat() function"
    check "endcall" '_bat "\$@"' "The file calls _bat \"\$@\" at the end"
    check "arguments" "_arguments" "The file uses _arguments"
    check "style" "\-\-style" "Option --style is defined"
    check "theme" "\-\-theme" "Option --theme is defined"
    check "language" "\-\-language" "Option --language is defined"
    check "list-themes" "list-themes" "Option --list-themes is defined"
    check "list-languages" "list-languages" "Option --list-languages is defined"
    check "color" "\-\-color" "Option --color is defined"
    check "paging" "\-\-paging" "Option --paging is defined"
    check "wrap" "\-\-wrap" "Option --wrap is defined"
    check "decorations" "decorations" "Option --decorations is defined (or --no-decorations)"
    check "help" "help" "Option --help is defined"
    ;;

  fzf)
    check "compdef" "^#compdef fzf" "The file starts with #compdef fzf"
    check "license" "Copyright" "The file has copyright/license header"
    check "function" "^_fzf\\(\\)" "The file defines a _fzf() function"
    check "endcall" '_fzf "\$@"' "The file calls _fzf \"\$@\" at the end"
    check "arguments" "_arguments" "The file uses _arguments"
    check "height" "\-\-height" "Option --height is defined"
    check "layout" "\-\-layout" "Option --layout is defined"
    check "reverse" "\-\-reverse" "Option --reverse is defined"
    check "bind" "\-\-bind" "Option --bind is defined"
    check "preview" "\-\-preview" "Option --preview is defined"
    check "preview-window" "preview-window" "Option --preview-window is defined"
    check "multi" "\-\-multi" "Option --multi is defined"
    check "query" "\-\-query" "Option --query is defined"
    check "select-1" "select-1" "Option --select-1 is defined"
    check "exit-0" "exit-0" "Option --exit-0 is defined"
    ;;

  *)
    echo "{\"expectations\":[],\"summary\":{\"passed\":0,\"failed\":1,\"total\":1,\"pass_rate\":0},\"error\":\"Unknown eval: $EVAL_NAME\"}"
    exit 1
    ;;
esac

PASS_RATE=$(python3 -c "print(round($PASSED / $TOTAL, 2))" 2>/dev/null || echo "0")

echo "$RESULTS" | python3 -c "
import json, sys
results = json.load(sys.stdin)
summary = {'passed': $PASSED, 'failed': $FAILED, 'total': $TOTAL, 'pass_rate': $PASS_RATE}
output = {'expectations': results, 'summary': summary}
print(json.dumps(output, indent=2))
"
