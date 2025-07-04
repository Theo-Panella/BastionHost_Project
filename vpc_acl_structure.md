## ⚠️ IMPORTANT ⚠️  
- We are talking about ACL (Stateless communication).  
- See the advice at the end of the document.  
- In this case, I allowed all protocol types in the ACLs — **not recommended** for production.  
- If you're building a company-level application, **research the necessary protocols** and limit ACL rules to only what's essential. This **increases security** and **reduces attack vectors** from invaders.

---

## 🌐 VPC 1 — ACL-SubNet_A, ACL-SubNet_B, and ACL-SubNet_C

### 🖧 ACL-SubNet_A

**Input rules:**
- Your own gateway IP address (used to connect to the Bastion Host)  
- SubNet_B IPv4 CIDR (allows SubNet_A to receive packets from SubNet_B)

**Output rules:**
- Your own gateway IP address (used to connect to the Bastion Host)  
- SubNet_B IPv4 CIDR (allows SubNet_A to send packets to SubNet_B)

---

### 🖧 ACL-SubNet_B

**Input rules:**
- SubNet_A IPv4 CIDR (allows SubNet_B to receive packets from SubNet_A)

**Output rules:**
- SubNet_A IPv4 CIDR (allows SubNet_B to send packets to SubNet_A)

---

### 🖧 ACL-SubNet_C

**Input rules:**
- Your own gateway IP address (used for private ACL access)  
- SubNet_B IPv4 CIDR (allows SubNet_C to receive packets from SubNet_B)

**Output rules:**
- Your own gateway IP address (used for private ACL access)  
- SubNet_B IPv4 CIDR (allows SubNet_C to send packets to SubNet_B)

---

### ‼️ Important to notice ‼️  
- SubNet_C **can** send and receive packets **to/from SubNet_B**,  
  **but SubNet_B is not configured to reciprocate**.  
- This happens because **ACL-SubNet_B only allows communication with SubNet_A**,  
  effectively blocking any communication with SubNet_C.

---

## 🌐 VPC 2

*(Reserved — no ACL rules defined yet)*

