# 📋 E-Governance Document Signing Smart Contract

A comprehensive Clarity smart contract for secure, transparent, and decentralized government document signing and verification on the Stacks blockchain.

## 🎯 Overview

This smart contract enables government authorities to create, sign, and manage official documents with full transparency and immutable records. Perfect for e-governance applications requiring multiple authority signatures and audit trails.

## ✨ Features

- 📄 **Document Creation**: Create official documents with metadata and required signature counts
- ✍️ **Multi-Signature Support**: Require multiple authority signatures before document completion
- 🔐 **Access Control**: Granular permissions for document access and signing rights
- 👥 **Authority Management**: Register and manage authorized government officials
- 🔒 **Document Sealing**: Permanently seal completed documents to prevent tampering
- 📊 **Audit Trail**: Complete history tracking of all document actions
- 🚨 **Signature Revocation**: Allow authorities to revoke signatures before sealing

## 🛠️ Contract Functions

### Public Functions

#### Authority Management
- `authorize-authority` - Register new government authority
- `set-authority-permissions` - Configure authority signing permissions

#### Document Operations
- `create-document` - Create new document requiring signatures
- `grant-document-access` - Grant access to specific users
- `sign-document` - Sign document with authority credentials
- `seal-document` - Permanently seal completed document
- `revoke-signature` - Remove signature from unsealed document

#### Read-Only Functions
- `get-document` - Retrieve document information
- `get-document-signatures` - Get signature details
- `get-authority-info` - Authority information lookup
- `get-document-access-level` - Check user access permissions
- `get-document-history` - View complete audit trail
- `get-document-status` - Current document state
- `has-signed-document` - Check if authority has signed
- `can-sign-document` - Verify signing eligibility

## 🚀 Quick Start

### 1. Deploy Contract
```bash
clarinet deploy --testnet
```

### 2. Authorize Government Authority
```clarity
(contract-call? .E-Governance-Document-Signing authorize-authority 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  "John Doe" 
  "Department of Health")
```

### 3. Create Official Document
```clarity
(contract-call? .E-Governance-Document-Signing create-document 
  "Health Certificate XYZ123" 
  0x1234567890abcdef1234567890abcdef12345678 
  u2)
```

### 4. Sign Document
```clarity
(contract-call? .E-Governance-Document-Signing sign-document 
  u1 
  0xabcdef1234567890abcdef1234567890abcdef12 
  "Approved by Health Department")
```

### 5. Seal Document
```clarity
(contract-call? .E-Governance-Document-Signing seal-document u1)
```

## 📊 Data Structures

### Document Structure
```clarity
{
  title: (string-ascii 100),
  hash: (buff 32),
  creator: principal,
  created-at: uint,
  status: (string-ascii 20),
  required-signatures: uint,
  signature-count: uint,
  sealed: bool
}
```

### Authority Structure
```clarity
{
  principal: principal,
  name: (string-ascii 50),
  department: (string-ascii 50),
  authorized-by: principal,
  created-at: uint,
  active: bool
}
```

## 🔍 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `err-owner-only` | Only contract owner can perform this action |
| u101 | `err-not-found` | Document or authority not found |
| u102 | `err-already-exists` | Resource already exists |
| u103 | `err-invalid-signer` | Signer not authorized |
| u104 | `err-already-signed` | Document already signed by this authority |
| u105 | `err-not-authorized` | Insufficient permissions |
| u106 | `err-invalid-status` | Invalid document status for operation |
| u107 | `err-document-sealed` | Cannot modify sealed document |

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

Check contract syntax:
```bash
clarinet check
```

## 🏛️ Use Cases

- **Municipal Permits**: Building permits, business licenses
- **Legal Documents**: Court orders, legal certifications
- **Healthcare**: Medical certifications, public health documents
- **Education**: Official transcripts, certification authorities
- **Identity**: Government ID verification, citizenship documents

## 🔧 Development

### Requirements
- [Clarinet](https://github.com/hirosystems/clarinet)
- Node.js 16+
- TypeScript

### Local Development
```bash
git clone <repository>
cd E-Governance-Document-Signing
clarinet check
clarinet test
```

## 🛡️ Security Features

- ✅ **Immutable Records**: Once sealed, documents cannot be modified
- ✅ **Multi-Signature Validation**: Requires multiple authority approvals
- ✅ **Access Control**: Granular permission system
- ✅ **Audit Trail**: Complete action history logging
- ✅ **Authority Verification**: Only registered authorities can sign

## 📈 Contract Statistics

- **Total Lines**: 250+ lines of clean Clarity code
- **Functions**: 15+ public and read-only functions
- **Data Maps**: 6 optimized storage maps
- **Error Handling**: Comprehensive error management

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

Built with ❤️ for transparent e-governance on Stacks blockchain
