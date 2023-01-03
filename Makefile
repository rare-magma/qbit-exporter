.PHONY: install
install:
	@mkdir --parents $${HOME}/.local/bin \
	&& mkdir --parents $${HOME}/.config/systemd/user \
	&& cp qbit_exporter.sh $${HOME}/.local/bin/ \
	&& chmod +x $${HOME}/.local/bin/qbit_exporter.sh \
	&& cp --no-clobber qbit_exporter.conf $${HOME}/.config/qbit_exporter.conf \
	&& chmod 400 $${HOME}/.config/qbit_exporter.conf \
	&& cp qbit-exporter.timer $${HOME}/.config/systemd/user/ \
	&& cp qbit-exporter.service $${HOME}/.config/systemd/user/ \
	&& systemctl --user enable --now qbit-exporter.timer

.PHONY: uninstall
uninstall:
	@rm -f $${HOME}/.local/bin/qbit_exporter.sh \
	&& rm -f $${HOME}/.config/qbit_exporter.conf \
	&& systemctl --user disable --now qbit-exporter.timer \
	&& rm -f $${HOME}/.config/.config/systemd/user/qbit-exporter.timer \
	&& rm -f $${HOME}/.config/systemd/user/qbit-exporter.service
