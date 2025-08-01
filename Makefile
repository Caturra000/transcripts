# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
SOURCEDIR     = .
BUILDDIR      = _build

# Put it first so that "make" without argument is like "make help".
#
# make server
# 启动一个简单的 http 服务器，指向 4000 端口
#
# make html
# 转发给 sphinx-build 构建 html 文件
help:
	@echo "make server"
	@echo "make html"
	@echo "=======sphinx======="
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

# make server 为调试模式，影响 conf.py 对文件后缀的处理
server:
	@make clean
	@export CATURRA_SPHINX_DEBUG=1 && make html
	python3 -m http.server 4000 -d _build/html/

.PHONY: help Makefile server

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
