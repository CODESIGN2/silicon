FROM ubuntu:16.04

ENV BUILDNUM=latest

RUN apt-get update -yqq && \
    apt-get install -yqq curl wget

RUN echo "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-5.0 main" > /etc/apt/sources.list.d/docker.list && \
    wget --quiet -O - http://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    apt-get update -yqq && \
    apt-get install -yqq clang-5.0 lldb-5.0 lld-5.0 libstdc++6 libc6-dev libc6 lcov

RUN apt-get install -yqq python3 python3-pip git \
    valgrind make cmake cppcheck

RUN pip3 install cpp-coveralls

RUN apt-get update --fix-missing -yqq && \
    apt-get install -yqq libboost-all-dev libssl-dev libsqlite3-dev libcurl4-openssl-dev libgnutls-dev libgcrypt-dev libmysqlclient-dev && \
    mkdir -p /build

COPY . /build

WORKDIR /build

RUN mkdir -p $HOME/local

ENV CXX=clang++-5.0
ENV CC=clang-5.0
ENV COMPILER=clang++-5.0

RUN git clone https://github.com/alanxz/rabbitmq-c.git && \
    mkdir -p rabbitmq-c/build && \
    cd rabbitmq-c/build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/local && \
    make -j 4 install

RUN wget --quiet http://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-0.9.48.tar.gz -O libmicrohttpd.tar.gz && \
    tar -xzf libmicrohttpd.tar.gz && \
    cd libmicrohttpd-0.9.48 && \
    ./configure --prefix=$HOME/local && \
    make -j 4 install

RUN git clone https://github.com/matt-42/iod.git && \
    mkdir -p iod/build && \
    cd iod/build && \
    ${CXX} --version && \
    cmake .. -DCMAKE_CXX_COMPILER=clang++-5.0 -DCMAKE_INSTALL_PREFIX=$HOME/local && \
    make -j 4 install

RUN mkdir -p ${BUILDNUM} && \
    cd ${BUILDNUM} && \
    cmake /build -DCMAKE_CXX_COMPILER=clang++-5.0 -DCMAKE_INSTALL_PREFIX=$HOME/local && \
    make install

ENV COVERALLS_REPO_TOKEN=ZRPgGdeGFA5rovrykguubKOqoKMIrDohy

RUN mkdir -p tests/${BUILDNUM} && \
    cd tests/${BUILDNUM} && \
    lcov -d ../.. --zerocounters && \
    cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/local && \
    make all test && \
    mkdir -p lcov && \
    lcov --no-external --capture --initial -d /build --output-file=lcov/tests.info \
        --gcov llvm-cov-5.0 && \
    lcov --remove lcov/tests.info 'tests/*' -o lcov/tests.info && \
    genhtml lcov/tests.info --output-directory lcov

# llvm-cov-5.0 gcov ../crud.cc -gcda=CMakeFiles/crud.dir/crud.cc.gcda -gcno=CMakeFiles/crud.dir/crud.cc.gcno

CMD ["/bin/bash"]
