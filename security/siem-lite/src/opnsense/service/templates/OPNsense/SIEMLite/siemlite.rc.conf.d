{% if helpers.exists('OPNsense.SIEMLite.general') %}
{% if OPNsense.SIEMLite.general.enabled|default('0') == '1' %}
siemlite_enable="YES"
{% else %}
siemlite_enable="NO"
{% endif %}
{% endif %}
