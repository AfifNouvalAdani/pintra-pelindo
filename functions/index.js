const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true }); // ✅ Tambahkan ini

admin.initializeApp();

exports.validateToken = functions.https.onRequest(async (req, res) => {
    // ✅ Enable CORS
    cors(req, res, async () => {
        try {
            const { token } = req.body;
            
            const tokenDoc = await admin.firestore()
                .collection('approval_tokens')
                .doc(token)
                .get();

            if (!tokenDoc.exists) {
                return res.json({ valid: false, message: 'Token tidak ditemukan' });
            }

            const tokenData = tokenDoc.data();
            const expiresAt = tokenData.expiresAt.toDate();
            const used = tokenData.used;

            if (new Date() > expiresAt) {
                return res.json({ valid: false, message: 'Token sudah kadaluarsa' });
            }

            if (used) {
                return res.json({ valid: false, message: 'Token sudah digunakan' });
            }

            return res.json({ 
                valid: true, 
                data: tokenData 
            });
            
        } catch (error) {
            console.error('Error validating token:', error);
            return res.status(500).json({ valid: false, error: error.message });
        }
    });
});

exports.approveBooking = functions.https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        try {
            const { bookingId, token, userId } = req.body;

            // 1. Validasi token dan user
            const tokenDoc = await admin.firestore()
                .collection('approval_tokens')
                .doc(token)
                .get();

            if (!tokenDoc.exists) {
                return res.json({ success: false, message: 'Token tidak valid' });
            }

            const tokenData = tokenDoc.data();
            
            // Cek token expired
            if (new Date() > tokenData.expiresAt.toDate()) {
                return res.json({ success: false, message: 'Token sudah kadaluarsa' });
            }

            if (tokenData.used) {
                return res.json({ success: false, message: 'Token sudah digunakan' });
            }

            if (tokenData.userId !== userId) {
                return res.json({ success: false, message: 'User tidak sesuai' });
            }

            // 2. Update booking status
            await admin.firestore()
                .collection('vehicle_bookings')
                .doc(bookingId)
                .update({
                    status: 'APPROVAL_1',
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    lastApprovalBy: userId
                });

            // 3. Mark token as used
            await admin.firestore()
                .collection('approval_tokens')
                .doc(token)
                .update({ 
                    used: true,
                    usedAt: admin.firestore.FieldValue.serverTimestamp()
                });

            return res.json({ success: true, message: 'Booking berhasil disetujui' });
            
        } catch (error) {
            console.error('Error approving booking:', error);
            return res.status(500).json({ success: false, error: error.message });
        }
    });
});

exports.rejectBooking = functions.https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        try {
            const { bookingId, token, userId, reason } = req.body;

            // 1. Validasi token
            const tokenDoc = await admin.firestore()
                .collection('approval_tokens')
                .doc(token)
                .get();

            if (!tokenDoc.exists) {
                return res.json({ success: false, message: 'Token tidak valid' });
            }

            const tokenData = tokenDoc.data();
            
            if (tokenData.userId !== userId) {
                return res.json({ success: false, message: 'User tidak sesuai' });
            }

            // 2. Update booking status
            await admin.firestore()
                .collection('vehicle_bookings')
                .doc(bookingId)
                .update({
                    status: 'CANCELLED',
                    rejectionReason: reason,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    rejectedBy: userId
                });

            // 3. Mark token as used
            await admin.firestore()
                .collection('approval_tokens')
                .doc(token)
                .update({ 
                    used: true,
                    usedAt: admin.firestore.FieldValue.serverTimestamp()
                });

            // 4. Tambahkan ke riwayat approval
            await admin.firestore()
                .collection('vehicle_bookings')
                .doc(bookingId)
                .collection('approval_history')
                .add({
                    action: 'REJECTED',
                    actionBy: userId,
                    reason: reason,
                    timestamp: admin.firestore.FieldValue.serverTimestamp()
                });

            return res.json({ success: true, message: 'Booking berhasil ditolak' });
            
        } catch (error) {
            console.error('Error rejecting booking:', error);
            return res.status(500).json({ success: false, error: error.message });
        }
    });
});