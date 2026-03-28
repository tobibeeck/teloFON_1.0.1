-- 001_initial.sql - teloFON Core Schema

-- Trigger Function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Tenants
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Admin Account (global, kein Tenant)
CREATE TABLE admin (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    extension VARCHAR(3) DEFAULT '000' UNIQUE NOT NULL,
    web_password_hash VARCHAR(255) NOT NULL,
    sip_password VARCHAR(255) NOT NULL,
    totp_secret VARCHAR(255),
    totp_enabled BOOLEAN DEFAULT false,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER trg_admin_updated_at BEFORE UPDATE ON admin FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Nebenstellen
CREATE TABLE extensions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    extension VARCHAR(5) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    web_password_hash VARCHAR(255) NOT NULL,
    sip_password VARCHAR(255) NOT NULL,
    voicemail_enabled BOOLEAN DEFAULT true,
    voicemail_pin VARCHAR(10),
    language VARCHAR(5) DEFAULT 'de',
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, extension)
);

CREATE INDEX idx_extensions_tenant ON extensions(tenant_id);
CREATE INDEX idx_extensions_extension ON extensions(tenant_id, extension);
CREATE TRIGGER trg_extensions_updated_at BEFORE UPDATE ON extensions FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- SIP Trunks
CREATE TABLE trunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    provider VARCHAR(255),
    host VARCHAR(255) NOT NULL,
    port INTEGER DEFAULT 5060,
    transport VARCHAR(10) DEFAULT 'TLS' CHECK (transport IN ('TLS', 'TCP', 'UDP')),
    username VARCHAR(255),
    password VARCHAR(255),
    auth_user VARCHAR(255),
    realm VARCHAR(255),
    ca_certificate TEXT,
    register BOOLEAN DEFAULT true,
    active BOOLEAN DEFAULT true,
    registration_status VARCHAR(50) DEFAULT 'unknown',
    last_registered TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_trunks_tenant ON trunks(tenant_id);
CREATE TRIGGER trg_trunks_updated_at BEFORE UPDATE ON trunks FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Ausgehende Regeln (mit Priorität)
CREATE TABLE outbound_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    pattern VARCHAR(255) NOT NULL,
    trunk_id UUID NOT NULL REFERENCES trunks(id),
    strip_digits INTEGER DEFAULT 0,
    prepend VARCHAR(50),
    priority INTEGER NOT NULL DEFAULT 0,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_outbound_rules_tenant ON outbound_rules(tenant_id);
CREATE INDEX idx_outbound_rules_priority ON outbound_rules(tenant_id, priority);
CREATE TRIGGER trg_outbound_rules_updated_at BEFORE UPDATE ON outbound_rules FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Routing Flows (React Flow CFD)
CREATE TABLE routing_flows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    flow_data JSONB NOT NULL DEFAULT '{}',
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_routing_flows_tenant ON routing_flows(tenant_id);
CREATE TRIGGER trg_routing_flows_updated_at BEFORE UPDATE ON routing_flows FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- IVR Ansagen / Audio Dateien
CREATE TABLE audio_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    filename VARCHAR(255) NOT NULL,
    duration_seconds INTEGER,
    language VARCHAR(5) DEFAULT 'de',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audio_files_tenant ON audio_files(tenant_id);

-- Action Codes
CREATE TABLE action_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    action_type VARCHAR(50) NOT NULL,
    action_data JSONB DEFAULT '{}',
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, code)
);

CREATE INDEX idx_action_codes_tenant ON action_codes(tenant_id);
CREATE TRIGGER trg_action_codes_updated_at BEFORE UPDATE ON action_codes FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Telefonbücher
CREATE TABLE phonebook_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    owner_extension_id UUID REFERENCES extensions(id) ON DELETE CASCADE,
    scope VARCHAR(20) NOT NULL DEFAULT 'global' CHECK (scope IN ('global', 'tenant', 'private')),
    first_name VARCHAR(255),
    last_name VARCHAR(255) NOT NULL,
    company VARCHAR(255),
    phone_numbers JSONB DEFAULT '[]',
    email VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_phonebook_tenant ON phonebook_entries(tenant_id);
CREATE INDEX idx_phonebook_scope ON phonebook_entries(scope);
CREATE INDEX idx_phonebook_owner ON phonebook_entries(owner_extension_id);
CREATE TRIGGER trg_phonebook_entries_updated_at BEFORE UPDATE ON phonebook_entries FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Call Detail Records (CDR)
CREATE TABLE cdr (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    call_uuid VARCHAR(255) UNIQUE NOT NULL,
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('inbound', 'outbound', 'internal')),
    from_number VARCHAR(50),
    to_number VARCHAR(50),
    from_extension VARCHAR(5),
    to_extension VARCHAR(5),
    trunk_id UUID REFERENCES trunks(id),
    start_time TIMESTAMPTZ NOT NULL,
    answer_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    duration_seconds INTEGER DEFAULT 0,
    billable_seconds INTEGER DEFAULT 0,
    hangup_cause VARCHAR(100),
    recording_file VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cdr_tenant ON cdr(tenant_id);
CREATE INDEX idx_cdr_start_time ON cdr(start_time);
CREATE INDEX idx_cdr_from_extension ON cdr(from_extension);
CREATE INDEX idx_cdr_to_extension ON cdr(to_extension);

-- Yealink Telefone / Geräte
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    extension_id UUID REFERENCES extensions(id) ON DELETE SET NULL,
    mac_address VARCHAR(17) UNIQUE NOT NULL,
    model VARCHAR(100),
    display_name VARCHAR(255),
    firmware_version VARCHAR(50),
    last_seen TIMESTAMPTZ,
    provisioning_url VARCHAR(500),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_devices_tenant ON devices(tenant_id);
CREATE INDEX idx_devices_mac ON devices(mac_address);
CREATE TRIGGER trg_devices_updated_at BEFORE UPDATE ON devices FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Audit Log (DSGVO)
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    actor VARCHAR(255) NOT NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),
    resource_id UUID,
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_log_tenant ON audit_log(tenant_id);
CREATE INDEX idx_audit_log_actor ON audit_log(actor);
CREATE INDEX idx_audit_log_created ON audit_log(created_at);

-- System Settings
CREATE TABLE settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    key VARCHAR(255) NOT NULL,
    value JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, key)
);

CREATE INDEX idx_settings_tenant ON settings(tenant_id);
CREATE TRIGGER trg_settings_updated_at BEFORE UPDATE ON settings FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Initial Seed Data
INSERT INTO settings (tenant_id, key, value) VALUES
    (NULL, 'system.languages', '["de", "en"]'),
    (NULL, 'system.default_language', '"de"'),
    (NULL, 'system.multi_tenant', 'false');
