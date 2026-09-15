#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 ))
then
  echo "Usage: $0 <PR_NUMBER> <FILE> [FILE ...]" >&2
  exit 1
fi

pr_number=$1
shift
files=("$@")

# current dirのrepositoryのPRを対象にする
pr_id=$(gh pr view "$pr_number" --json id --jq '.id')

batch_size=100

for ((offset = 0; offset < ${#files[@]}; offset += batch_size))
do
  batch=("${files[@]:offset:batch_size}")

  var_defs='$pr: ID!'
  body=''
  args=(-F "pr=$pr_id")

  for ((i = 0; i < ${#batch[@]}; i++))
  do
    var="path$i"

    var_defs+=", \$$var: String!"

    body+="
      file$i: markFileAsViewed(input: {
        pullRequestId: \$pr
        path: \$$var
      }) {
        clientMutationId
      }
    "

    args+=(-F "$var=${batch[$i]}")
  done

  query="
    mutation($var_defs) {
      $body
    }
  "

  echo "Marking files $((offset + 1))-$((offset + ${#batch[@]})) as viewed..." >&2

  echo gh api graphql "${args[@]}" -f query="$query"
done
