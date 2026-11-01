#!/usr/bin/env bash
# Downloads the embedded speech model into assets/speech_model/, which git ignores.
# A build without it still works: the Embedded engine reports itself unavailable.
set -euo pipefail

readonly model="sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile"
readonly url="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${model}.tar.bz2"
readonly sha256="4dad6f4849cad551042eb875505b3fdc0fac9f1c88d709165c48b921681e61dc"
readonly files=(
  "encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx"
  "decoder-epoch-99-avg-1-chunk-16-left-128.onnx"
  "joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx"
  "tokens.txt"
)

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly target="${script_directory}/../assets/speech_model"

missing=false
for file in "${files[@]}"; do
  [[ -f "${target}/${file}" ]] || missing=true
done
if [[ "${missing}" == false ]]; then
  echo "The speech model is already in place."
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

curl --fail --location --retry 3 --silent --show-error --output "${work}/model.tar.bz2" "${url}"
echo "${sha256}  ${work}/model.tar.bz2" | shasum --algorithm 256 --check --status

members=()
for file in "${files[@]}"; do
  members+=("${model}/${file}")
done
tar --extract --bzip2 --file "${work}/model.tar.bz2" --directory "${work}" "${members[@]}"

mkdir -p "${target}"
for file in "${files[@]}"; do
  mv "${work}/${model}/${file}" "${target}/${file}"
done
echo "The speech model is in ${target}."
