export const openApiSpecification = {
  openapi: '3.0.3',
  info: {
    title: 'Vega (वेग) Universal P2P Transfer & Sync API',
    version: '1.0.0',
    description:
      'Offline-first peer-to-peer file transfer, cryptographic QR pairing, cross-platform folder synchronization, SHA-256 verification, and audit telemetry API by Manatwal Innovations.',
    contact: {
      name: 'Manatwal Innovations',
    },
    license: {
      name: 'Apache-2.0',
    },
  },
  servers: [
    {
      url: '/',
      description: 'Local Vega Signaling & Sync Node',
    },
  ],
  tags: [
    { name: 'System', description: 'Health and real-time system performance monitoring' },
    { name: 'Peers & Pairing', description: 'Live peer discovery and expiring QR pairing sessions' },
    { name: 'File Vault & Transfers', description: 'Chunked resumable transfers, SHA-256 verification, and history' },
    { name: 'Folder Sync', description: 'Shared sync folders, granular permissions, and conflict resolution' },
    { name: 'Audit & Security', description: 'Tamper-evident security and transfer audit logs' },
  ],
  paths: {
    '/api/health': {
      get: {
        tags: ['System'],
        summary: 'Service health check',
        responses: {
          '200': {
            description: 'Node is operational and ready for P2P signaling',
          },
        },
      },
    },
    '/api/monitoring/metrics': {
      get: {
        tags: ['System'],
        summary: 'Real-time system & transfer performance metrics',
        responses: {
          '200': {
            description: 'Live CPU/memory, active peer count, throughput, and verification metrics',
          },
        },
      },
    },
    '/api/peers': {
      get: {
        tags: ['Peers & Pairing'],
        summary: 'List currently connected real WebSocket peers',
        responses: {
          '200': {
            description: 'Array of live connected devices',
          },
        },
      },
    },
    '/api/pairing/create': {
      post: {
        tags: ['Peers & Pairing'],
        summary: 'Create an expiring cryptographic QR pairing session (120s TTL)',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['peerId', 'deviceName', 'platform'],
                properties: {
                  peerId: { type: 'string' },
                  deviceName: { type: 'string' },
                  platform: { type: 'string', enum: ['android', 'windows', 'macos', 'linux', 'web'] },
                  fingerprint: { type: 'string' },
                  publicKeyJwk: { type: 'object' },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Pairing session created with QR PNG data URL' },
        },
      },
    },
    '/api/pairing/{token}': {
      get: {
        tags: ['Peers & Pairing'],
        summary: 'Validate a pairing token before requesting approval',
        parameters: [
          { name: 'token', in: 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Valid pairing session metadata' },
          '404': { description: 'Token not found' },
          '410': { description: 'Pairing token expired' },
        },
      },
    },
    '/api/history': {
      get: {
        tags: ['File Vault & Transfers'],
        summary: 'Retrieve transfer history records',
        responses: { '200': { description: 'List of transfer history records' } },
      },
      post: {
        tags: ['File Vault & Transfers'],
        summary: 'Record a completed, failed, or cancelled transfer',
        responses: { '201': { description: 'History record persisted' } },
      },
      delete: {
        tags: ['File Vault & Transfers'],
        summary: 'Clear all or selected transfer history records',
        responses: { '200': { description: 'Records cleared' } },
      },
    },
    '/api/folders': {
      get: {
        tags: ['Folder Sync'],
        summary: 'List shared synchronization folders and granular permissions',
        responses: { '200': { description: 'Shared folder configurations and manifests' } },
      },
      post: {
        tags: ['Folder Sync'],
        summary: 'Create a new shared sync folder',
        responses: { '201': { description: 'Shared folder created' } },
      },
    },
    '/api/folders/{folderId}/permissions': {
      put: {
        tags: ['Folder Sync'],
        summary: 'Update granular peer permissions (admin, write, read, revoked) for a shared folder',
        parameters: [
          { name: 'folderId', in: 'path', required: true, schema: { type: 'string' } },
        ],
        responses: { '200': { description: 'Permissions updated and audited' } },
      },
    },
    '/api/folders/{folderId}/resolve-conflict': {
      post: {
        tags: ['Folder Sync'],
        summary: 'Resolve a synchronization conflict on a file entry',
        parameters: [
          { name: 'folderId', in: 'path', required: true, schema: { type: 'string' } },
        ],
        responses: { '200': { description: 'Conflict resolved and audited' } },
      },
    },
    '/api/audit-logs': {
      get: {
        tags: ['Audit & Security'],
        summary: 'Query tamper-evident security and transfer audit logs',
        responses: { '200': { description: 'Array of audit log entries' } },
      },
    },
  },
};
