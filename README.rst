Archlinux Bootstrap
===================

.. image:: https://travis-ci.org/EricCrosson/archlinux-install.svg?branch=master
   :target: https://travis-ci.org/EricCrosson/archlinux-install

Inspired by `wuputah <https://github.com/wuputah>`_'s vm-bootstrapping
`gist <https://gist.github.com/wuputah/4982514>`_, this script
interfaces with the `Arch GNU/Linux <https://www.archlinux.org/>`_
installer shell and provisions a simple, working system.

Also included is an ansible role to configure my personal hosts.

Installation
------------

You can dump this into your shell to run the script

.. code-block:: bash

    sh -c "$(curl -fsSL https://raw.githubusercontent.com/EricCrosson/archlinux-install/master/scripts/archlinux-install.sh)"
    # sh -c "$(curl -fsSL https://goo.gl/SdF6YW)"

Or, if you prefer editing the script first

.. code-block:: bash

    wget -O installer.sh https://raw.githubusercontent.com/EricCrosson/archlinux-install/master/archlinux-install.sh && \
    chmod +x installer.sh && \
    vi installer.sh && ./installer.sh

After provisioning from inside the installer, configure
:code:`/roles/common/vars/main.yml` and run

.. code-block:: bash

    ansible-playbook -i hosts site.yml

Credits
-------

Original gist by `wuputah <https://gist.github.com/wuputah/4982514>`_.
