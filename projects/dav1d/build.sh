#!/bin/bash -eu
# Copyright 2018 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

# setup
build=${WORK}/build

# cleanup
rm -rf ${build}
mkdir -p ${build}

# build library
BUILD_ASM="true"

# MemorySanitizer may report false positives if used with asm code.
if [[ $CFLAGS = *sanitize=memory* ]]
then
  BUILD_ASM="false"
else
	# Build the specific nasm version without memory instrumentation.
	pushd $SRC

	BUILD_DEPS="$SRC/build_deps"
	mkdir -p $BUILD_DEPS

	tar xzf nasm-*
	cd nasm-*
	CFLAGS="" CXXFLAGS="" ./configure --prefix="$BUILD_DEPS"
	make clean
	make -j$(nproc)
	make install

	export PATH="$BUILD_DEPS/bin:$PATH"
	export LD_LIBRARY_PATH="$BUILD_DEPS/lib"
	popd
fi

meson -Dbuild_asm=$BUILD_ASM -Dbuild_tools=false -Dfuzzing_engine=oss-fuzz \
      -Db_lundef=false -Ddefault_library=static -Dbuildtype=debugoptimized \
      ${build}
ninja -j $(nproc) -C ${build}

# prepare seed corpus
rm -rf ${WORK}/tmp
mkdir -p ${WORK}/tmp/testdata
unzip -q $SRC/dav1d_fuzzer_seed_corpus.zip -d ${WORK}/tmp/testdata
cp $SRC/dec_fuzzer_seed_corpus.zip ${WORK}/tmp/seed_corpus.zip
(cd ${WORK}/tmp && zip -q -m -r -0 ${WORK}/tmp/seed_corpus.zip testdata)

# copy fuzzers and link testdata
for fuzzer in $(find ${build} -name 'dav1d_fuzzer*'); do
	cp "${fuzzer}" $OUT/
	cp ${WORK}/tmp/seed_corpus.zip $OUT/$(basename "$fuzzer")_seed_corpus.zip
	cp $SRC/fuzzer.options $OUT/$(basename "$fuzzer").options
done
