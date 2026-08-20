import { ref, onValue, set, update, push, get } from 'firebase/database';
import { db } from '../config/firebase';
import {
  UserProfile,
  Booking,
  ParkingSpace,
  PayoutRequest,
  SupportTicket,
  SupportMessage,
  WalletTransaction,
  DashboardMetrics,
  AdminBasePricing,
  PartnerApprovalRequest,
  Offer,
} from '../types';

export class FirebaseAdminService {
  // ==========================================
  // 1. BOOKINGS STREAM & ACTIONS
  // ==========================================
  static subscribeBookings(callback: (bookings: Booking[]) => void): () => void {
    const bookingsRef = ref(db, 'bookings');
    const unsubscribe = onValue(
      bookingsRef,
      (snapshot) => {
        const val = snapshot.val();
        if (!val || typeof val !== 'object') {
          callback([]);
          return;
        }
        const list: Booking[] = Object.entries(val).map(([id, data]) => {
          const item = data as any;
          return {
            id: item.id || id,
            userId: item.userId || '',
            spaceId: item.spaceId || '',
            partnerId: item.partnerId || '',
            spaceTitle: item.spaceTitle || 'Parking Space',
            spaceAddress: item.spaceAddress || '',
            vehicleNumber: item.vehicleNumber || 'N/A',
            vehicleModel: item.vehicleModel || '',
            vehicleType: item.vehicleType || 'Car',
            bookingDate: item.bookingDate || '',
            timeSlot: item.timeSlot || '',
            durationType: item.durationType || 'hourly',
            totalAmount: Number(item.totalAmount) || 0,
            paymentId: item.paymentId || '',
            status: (item.status || 'upcoming').toLowerCase(),
            createdAt: item.createdAt || new Date().toISOString(),
            userRating: item.userRating ? Number(item.userRating) : undefined,
            userReview: item.userReview || undefined,
          };
        });
        // Sort newest first
        list.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
        callback(list);
      },
      (error) => {
        console.error('Error streaming bookings:', error);
        callback([]);
      }
    );
    return () => unsubscribe();
  }

  static async updateBookingStatus(bookingId: string, status: string): Promise<void> {
    const bookingRef = ref(db, `bookings/${bookingId}`);
    await update(bookingRef, { status: status.toLowerCase() });
  }

  static async deleteBooking(bookingId: string): Promise<void> {
    const bookingRef = ref(db, `bookings/${bookingId}`);
    await set(bookingRef, null);
  }

  static async cancelAndRefundBooking(booking: Booking, refundAmount: number, reason: string): Promise<void> {
    // 1. Update Booking status to cancelled
    await this.updateBookingStatus(booking.id, 'cancelled');

    // 2. Refund to Seeker Wallet if amount > 0
    if (refundAmount > 0 && booking.userId) {
      await this.adjustUserWallet(
        booking.userId,
        refundAmount,
        'credit',
        'Booking Refund',
        `Admin Refund for ${booking.spaceTitle} (${reason || 'Reservation Cancelled'})`
      );
    }
  }

  // ==========================================
  // 2. USERS & SEEKERS STREAM & ACTIONS
  // ==========================================
  static subscribeUsers(callback: (users: UserProfile[]) => void): () => void {
    const usersRef = ref(db, 'users');
    const unsubscribe = onValue(
      usersRef,
      (snapshot) => {
        const val = snapshot.val();
        if (!val || typeof val !== 'object') {
          callback([]);
          return;
        }
        const list: UserProfile[] = Object.entries(val).map(([uid, raw]) => {
          const u = raw as any;
          const profile = (u.profile && typeof u.profile === 'object') ? u.profile : u;
          
          let vehiclesList = [];
          if (Array.isArray(profile.vehicles)) {
            vehiclesList = profile.vehicles;
          } else if (u.vehicles && typeof u.vehicles === 'object') {
            vehiclesList = Object.values(u.vehicles);
          }

          return {
            uid: profile.uid || uid,
            name: profile.name || 'User',
            email: profile.email || '',
            phone: profile.phone || '',
            role: profile.role || 'user',
            photoUrl: profile.photoUrl || '',
            walletBalance: Number(u.walletBalance ?? profile.walletBalance ?? 0),
            fcmToken: profile.fcmToken || '',
            vehicles: vehiclesList,
            bankDetails: profile.bankDetails || u.bankDetails,
            businessName: profile.businessName || u.businessName,
            address: profile.address || u.address,
            status: profile.status || 'active',
            isApproved: profile.isApproved ?? (profile.role === 'partner' ? false : true),
            createdAt: profile.createdAt || new Date().toISOString(),
          };
        });
        callback(list);
      },
      (error) => {
        console.error('Error streaming users:', error);
        callback([]);
      }
    );
    return () => unsubscribe();
  }

  static async updateUserStatus(uid: string, status: 'active' | 'suspended' | 'pending'): Promise<void> {
    const updates: Record<string, any> = {};
    updates[`users/${uid}/status`] = status;
    updates[`users/${uid}/profile/status`] = status;
    await update(ref(db), updates);
  }

  static async adjustUserWallet(
    userId: string,
    amount: number,
    type: 'credit' | 'debit',
    title: string,
    subtitle: string
  ): Promise<void> {
    const userWalletRef = ref(db, `users/${userId}/walletBalance`);
    const snap = await get(userWalletRef);
    const currentBal = Number(snap.val()) || 0;
    const cleanAmount = Math.abs(amount);
    const newBal = type === 'credit' ? currentBal + cleanAmount : Math.max(0, currentBal - cleanAmount);

    // 1. Update wallet balance
    await set(userWalletRef, newBal);

    // 2. Also sync to profile node if present
    const profileWalletRef = ref(db, `users/${userId}/profile/walletBalance`);
    try {
      await set(profileWalletRef, newBal);
    } catch (_) {}

    // 3. Log wallet transaction
    const txRef = push(ref(db, 'walletTransactions'));
    const tx: WalletTransaction = {
      id: txRef.key || `tx_${Date.now()}`,
      title,
      subtitle,
      amount: cleanAmount,
      date: new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }),
      type,
      timestamp: Date.now(),
      userId,
    };
    await set(txRef, tx);
  }

  // ==========================================
  // 3. PARTNERS & APPROVALS
  // ==========================================
  static async approvePartner(uid: string): Promise<void> {
    const updates: Record<string, any> = {};
    updates[`users/${uid}/isApproved`] = true;
    updates[`users/${uid}/status`] = 'active';
    updates[`users/${uid}/profile/isApproved`] = true;
    updates[`users/${uid}/profile/status`] = 'active';
    updates[`partners/${uid}/isApproved`] = true;
    updates[`partners/${uid}/verifiedAt`] = new Date().toISOString();
    await update(ref(db), updates);
  }

  static async rejectPartner(uid: string, reason: string): Promise<void> {
    const updates: Record<string, any> = {};
    updates[`users/${uid}/isApproved`] = false;
    updates[`users/${uid}/status`] = 'suspended';
    updates[`users/${uid}/profile/isApproved`] = false;
    updates[`users/${uid}/profile/rejectionReason`] = reason;
    await update(ref(db), updates);
  }

  // ==========================================
  // 4. PARKING SPACES & LISTINGS APPROVALS
  // ==========================================
  static subscribeParkingSpaces(callback: (spaces: ParkingSpace[]) => void): () => void {
    const spacesRef = ref(db, 'parkingSpaces');
    const unsubscribe = onValue(
      spacesRef,
      (snapshot) => {
        const val = snapshot.val();
        if (!val || typeof val !== 'object') {
          callback([]);
          return;
        }
        const list: ParkingSpace[] = Object.entries(val).map(([id, raw]) => {
          const s = raw as any;
          const lat = Number(s.lat ?? s.latitude ?? 0);
          const lng = Number(s.lng ?? s.longitude ?? 0);

          const maxCars = Number(s.capacity?.maxCars ?? s.totalSlots ?? s.capacity ?? 10);
          const currentCars = Number(s.capacity?.currentCars ?? 0);
          const availableSlots = Number(s.availableSlots ?? (maxCars - currentCars > 0 ? maxCars - currentCars : 0));

          let imagesList: string[] = [];
          if (Array.isArray(s.images)) {
            imagesList = s.images;
          } else if (s.image) {
            imagesList = [s.image];
          } else if (s.photoUrl) {
            imagesList = [s.photoUrl];
          }

          return {
            id: s.id || id,
            ownerId: s.ownerId || '',
            title: s.title || 'Untitled Space',
            address: s.address || s.city || '',
            latitude: lat,
            longitude: lng,
            pricing: {
              hourly: Number(s.pricing?.hourly ?? s.hourlyPrice ?? 40),
              daily: Number(s.pricing?.daily ?? s.dailyPrice ?? 300),
              weekly: Number(s.pricing?.weekly ?? 1500),
              monthly: Number(s.pricing?.monthly ?? 4500),
            },
            totalSlots: maxCars,
            availableSlots: availableSlots,
            isActive: s.status === 'active' || s.isActive === true,
            status: s.status || (s.isActive ? 'approved' : 'pending'),
            images: imagesList,
            amenities: Array.isArray(s.amenities) ? s.amenities : [],
            isEvCharging: Boolean(s.hasEvCharging || s.isEvCharging || (Array.isArray(s.amenities) && s.amenities.some((a: string) => a.toLowerCase().includes('ev')))),
            polygonCoordinates: Array.isArray(s.polygonCoordinates) ? s.polygonCoordinates : undefined,
            totalLandSqMeters: Number(s.capacity?.totalLandSqMeters ?? s.totalLandSqMeters ?? 150),
            createdAt: s.createdAt || new Date().toISOString(),
          };
        });
        callback(list);
      },
      (error) => {
        console.error('Error streaming spaces:', error);
        callback([]);
      }
    );
    return () => unsubscribe();
  }

  static async approveParkingSpace(spaceId: string): Promise<void> {
    const spaceRef = ref(db, `parkingSpaces/${spaceId}`);
    await update(spaceRef, {
      status: 'approved',
      isActive: true,
      approvedAt: new Date().toISOString(),
    });
  }

  static async rejectParkingSpace(spaceId: string, reason: string): Promise<void> {
    const spaceRef = ref(db, `parkingSpaces/${spaceId}`);
    await update(spaceRef, {
      status: 'rejected',
      isActive: false,
      rejectionReason: reason,
    });
  }

  static async toggleSpaceActive(spaceId: string, isActive: boolean): Promise<void> {
    const spaceRef = ref(db, `parkingSpaces/${spaceId}`);
    await update(spaceRef, { isActive });
  }

  // ==========================================
  // 5. PAYOUTS & DISBURSEMENTS
  // ==========================================
  static subscribePayouts(callback: (payouts: PayoutRequest[]) => void): () => void {
    const payoutsRef = ref(db, 'payouts');
    const unsubscribe = onValue(
      payoutsRef,
      (snapshot) => {
        const val = snapshot.val();
        if (!val || typeof val !== 'object') {
          callback([]);
          return;
        }
        const list: PayoutRequest[] = Object.entries(val).map(([id, raw]) => {
          const p = raw as any;
          return {
            id: p.id || id,
            partnerId: p.partnerId || '',
            partnerName: p.partnerName || 'Partner',
            partnerEmail: p.partnerEmail || '',
            partnerPhone: p.partnerPhone || '',
            amount: Number(p.amount) || 0,
            status: (p.status || 'pending').toLowerCase(),
            bankDetails: p.bankDetails,
            requestedAt: p.requestedAt || new Date().toISOString(),
            processedAt: p.processedAt,
            referenceNumber: p.referenceNumber,
            notes: p.notes,
          };
        });
        list.sort((a, b) => new Date(b.requestedAt).getTime() - new Date(a.requestedAt).getTime());
        callback(list);
      },
      (error) => {
        console.error('Error streaming payouts:', error);
        callback([]);
      }
    );
    return () => unsubscribe();
  }

  static async processPayout(payoutId: string, referenceNumber: string, notes?: string): Promise<void> {
    const payoutRef = ref(db, `payouts/${payoutId}`);
    await update(payoutRef, {
      status: 'processed',
      referenceNumber: referenceNumber || `PAY_${Date.now()}`,
      processedAt: new Date().toISOString(),
      notes: notes || 'Disbursed via Direct Bank Transfer',
    });
  }

  static async rejectPayout(payoutId: string, reason: string): Promise<void> {
    const payoutRef = ref(db, `payouts/${payoutId}`);
    await update(payoutRef, {
      status: 'rejected',
      processedAt: new Date().toISOString(),
      notes: reason,
    });
  }

  // ==========================================
  // 6. SUPPORT TICKETS & DISPUTES
  // ==========================================
  static subscribeSupportTickets(callback: (tickets: SupportTicket[]) => void): () => void {
    const ticketsRef = ref(db, 'supportTickets');
    const unsubscribe = onValue(
      ticketsRef,
      (snapshot) => {
        const val = snapshot.val();
        if (!val || typeof val !== 'object') {
          callback([]);
          return;
        }
        const list: SupportTicket[] = Object.entries(val).map(([id, raw]) => {
          const t = raw as any;
          return {
            id: t.id || id,
            userId: t.userId || '',
            userName: t.userName || 'Customer',
            userEmail: t.userEmail || '',
            userPhone: t.userPhone || '',
            userRole: t.userRole || 'user',
            subject: t.subject || 'Support Inquiry',
            description: t.description || '',
            category: t.category || 'general',
            status: t.status || 'open',
            priority: t.priority || 'medium',
            createdAt: t.createdAt || new Date().toISOString(),
            updatedAt: t.updatedAt,
            resolutionNotes: t.resolutionNotes,
          };
        });
        list.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
        callback(list);
      },
      (error) => {
        console.error('Error streaming tickets:', error);
        callback([]);
      }
    );
    return () => unsubscribe();
  }

  static async updateTicketStatus(
    ticketId: string,
    status: 'open' | 'in_progress' | 'resolved' | 'closed',
    resolutionNotes?: string
  ): Promise<void> {
    const ticketRef = ref(db, `supportTickets/${ticketId}`);
    await update(ticketRef, {
      status,
      updatedAt: new Date().toISOString(),
      ...(resolutionNotes ? { resolutionNotes } : {}),
    });
  }

  static async createSupportTicket(ticket: Omit<SupportTicket, 'id'>): Promise<string> {
    const ticketRef = push(ref(db, 'supportTickets'));
    const newId = ticketRef.key || `TICK_${Date.now()}`;
    await set(ticketRef, { ...ticket, id: newId });
    return newId;
  }

  static subscribeTicketMessages(ticketId: string, callback: (messages: SupportMessage[]) => void): () => void {
    const msgsRef = ref(db, `supportTickets/${ticketId}/messages`);
    const unsubscribe = onValue(
      msgsRef,
      (snapshot) => {
        const val = snapshot.val();
        if (!val || typeof val !== 'object') {
          callback([]);
          return;
        }
        const list: SupportMessage[] = Object.entries(val).map(([id, raw]) => {
          const m = raw as any;
          return {
            id: m.id || id,
            senderId: m.senderId || 'admin',
            senderName: m.senderName || 'Mee Parking Support',
            senderRole: m.senderRole || 'admin',
            text: m.text || '',
            timestamp: m.timestamp || new Date().toISOString(),
          };
        });
        list.sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
        callback(list);
      },
      (error) => {
        console.error('Error streaming ticket messages:', error);
        callback([]);
      }
    );
    return () => unsubscribe();
  }

  static async sendTicketMessage(
    ticketId: string,
    message: { senderId: string; senderName: string; senderRole: 'admin' | 'user' | 'partner'; text: string }
  ): Promise<void> {
    const msgsRef = ref(db, `supportTickets/${ticketId}/messages`);
    const newMsgRef = push(msgsRef);
    const msgId = newMsgRef.key || `MSG_${Date.now()}`;
    const timestamp = new Date().toISOString();

    await set(newMsgRef, {
      id: msgId,
      ...message,
      timestamp,
    });

    // Update ticket's lastMessage and updatedAt and set to in_progress if currently open
    const ticketRef = ref(db, `supportTickets/${ticketId}`);
    await update(ticketRef, {
      lastMessage: message.text,
      updatedAt: timestamp,
      status: 'in_progress',
    });
  }

  // ==========================================
  // 7. DASHBOARD METRICS CALCULATION
  // ==========================================
  static computeMetrics(
    bookings: Booking[],
    users: UserProfile[],
    spaces: ParkingSpace[],
    payouts: PayoutRequest[],
    tickets: SupportTicket[]
  ): DashboardMetrics {
    const totalRevenue = bookings
      .filter((b) => b.status === 'completed' || b.status === 'confirmed' || b.status === 'upcoming')
      .reduce((sum, b) => sum + (b.totalAmount || 0), 0);

    const activeBookings = bookings.filter(
      (b) => b.status === 'upcoming' || b.status === 'in-progress' || b.status === 'confirmed'
    ).length;

    const completedBookings = bookings.filter((b) => b.status === 'completed').length;
    const cancelledBookings = bookings.filter((b) => b.status === 'cancelled').length;

    const drivers = users.filter((u) => u.role !== 'partner');
    const partners = users.filter((u) => u.role === 'partner');
    const pendingPartnerApprovals = partners.filter((p) => !p.isApproved || p.status === 'pending').length;

    const activeSpaces = spaces.filter((s) => s.isActive && s.status === 'approved').length;
    const pendingSpaceApprovals = spaces.filter((s) => s.status === 'pending' || !s.status).length;

    const pendingPayoutsAmount = payouts
      .filter((p) => p.status === 'pending')
      .reduce((sum, p) => sum + (p.amount || 0), 0);

    const openSupportTickets = tickets.filter((t) => t.status === 'open' || t.status === 'in_progress').length;

    return {
      totalRevenue,
      totalBookings: bookings.length,
      activeBookings,
      completedBookings,
      cancelledBookings,
      totalUsers: drivers.length,
      totalPartners: partners.length,
      pendingPartnerApprovals,
      totalSpaces: spaces.length,
      activeSpaces,
      pendingSpaceApprovals,
      pendingPayoutsAmount,
      openSupportTickets,
    };
  }

  // ==========================================
  // 8. ADMIN BASE PRICING & TARIFF MATRIX
  // ==========================================
  static subscribeBasePricing(callback: (pricing: AdminBasePricing) => void): () => void {
    const pricingRef = ref(db, 'adminConfig/basePricing');
    const unsubscribe = onValue(
      pricingRef,
      (snapshot) => {
        const val = snapshot.val();
        if (!val || typeof val !== 'object') {
          // Fallback defaults
          callback({
            twoWheeler: { hourly: 30, daily: 150, weekly: 750, monthly: 2250 },
            threeWheeler: { hourly: 45, daily: 225, weekly: 1125, monthly: 3375 },
            fourWheeler: { hourly: 60, daily: 300, weekly: 1500, monthly: 4500 },
          });
          return;
        }
        callback({
          twoWheeler: {
            hourly: Number(val.twoWheeler?.hourly ?? 30),
            daily: Number(val.twoWheeler?.daily ?? 150),
            weekly: Number(val.twoWheeler?.weekly ?? 750),
            monthly: Number(val.twoWheeler?.monthly ?? 2250),
          },
          threeWheeler: {
            hourly: Number(val.threeWheeler?.hourly ?? 45),
            daily: Number(val.threeWheeler?.daily ?? 225),
            weekly: Number(val.threeWheeler?.weekly ?? 1125),
            monthly: Number(val.threeWheeler?.monthly ?? 3375),
          },
          fourWheeler: {
            hourly: Number(val.fourWheeler?.hourly ?? 60),
            daily: Number(val.fourWheeler?.daily ?? 300),
            weekly: Number(val.fourWheeler?.weekly ?? 1500),
            monthly: Number(val.fourWheeler?.monthly ?? 4500),
          },
          updatedAt: val.updatedAt || undefined,
          updatedBy: val.updatedBy || 'Super Admin',
        });
      },
      (error) => {
        console.error('Error streaming base pricing:', error);
        callback({
          twoWheeler: { hourly: 30, daily: 150, weekly: 750, monthly: 2250 },
          threeWheeler: { hourly: 45, daily: 225, weekly: 1125, monthly: 3375 },
          fourWheeler: { hourly: 60, daily: 300, weekly: 1500, monthly: 4500 },
        });
      }
    );
    return () => unsubscribe();
  }

  static async saveBasePricing(pricing: AdminBasePricing): Promise<void> {
    const pricingRef = ref(db, 'adminConfig/basePricing');
    await set(pricingRef, {
      ...pricing,
      updatedAt: new Date().toISOString(),
      updatedBy: 'Admin Console',
    });
  }

  // ==========================================
  // 9. PARTNER LISTING APPROVAL REQUESTS
  // ==========================================
  static subscribePartnerRequests(callback: (requests: PartnerApprovalRequest[]) => void): () => void {
    const requestsRef = ref(db, 'admin/partnerRequests');
    const unsubscribe = onValue(
      requestsRef,
      (snapshot) => {
        const val = snapshot.val();
        if (!val || typeof val !== 'object') {
          callback([]);
          return;
        }
        const list: PartnerApprovalRequest[] = Object.entries(val).map(([spaceId, data]) => {
          const item = data as any;
          return {
            spaceId: item.spaceId || spaceId,
            ownerId: item.ownerId || '',
            partnerName: item.partnerName || 'Partner',
            partnerPhone: item.partnerPhone || '',
            partnerEmail: item.partnerEmail || '',
            spaceTitle: item.spaceTitle || 'Parking Space',
            address: item.address || '',
            city: item.city || '',
            status: item.status || 'pending_approval',
            totalLandSqMeters: Number(item.totalLandSqMeters || 0),
            maxCars: Number(item.maxCars || 0),
            maxBikes: Number(item.maxBikes || 0),
            images: Array.isArray(item.images) ? item.images : [],
            pricing: item.pricing || undefined,
            submittedAt: item.submittedAt || new Date().toISOString(),
            rejectionReason: item.rejectionReason,
          };
        });
        list.sort((a, b) => new Date(b.submittedAt).getTime() - new Date(a.submittedAt).getTime());
        callback(list);
      },
      (error) => {
        console.error('Error streaming partner requests:', error);
        callback([]);
      }
    );
    return () => unsubscribe();
  }

  static async approvePartnerRequest(spaceId: string): Promise<void> {
    const requestRef = ref(db, `admin/partnerRequests/${spaceId}`);
    const spaceRef = ref(db, `parkingSpaces/${spaceId}`);
    await update(requestRef, {
      status: 'approved',
      approvedAt: new Date().toISOString(),
    });
    await update(spaceRef, {
      status: 'active',
      isActive: true,
      approvedAt: new Date().toISOString(),
    });
  }

  static async rejectPartnerRequest(spaceId: string, reason: string): Promise<void> {
    const requestRef = ref(db, `admin/partnerRequests/${spaceId}`);
    const spaceRef = ref(db, `parkingSpaces/${spaceId}`);
    await update(requestRef, {
      status: 'rejected',
      rejectionReason: reason,
      rejectedAt: new Date().toISOString(),
    });
    await update(spaceRef, {
      status: 'rejected',
      isActive: false,
      rejectionReason: reason,
    });
  }

  // ==========================================
  // 9. PROMOTIONS, OFFERS & COUPONS
  // ==========================================
  static subscribeOffers(callback: (offers: Offer[]) => void): () => void {
    const offersRef = ref(db, 'offers');
    const unsubscribe = onValue(
      offersRef,
      (snapshot) => {
        const val = snapshot.val();
        if (!val || typeof val !== 'object') {
          // If empty, seed default platform offers
          this.seedInitialOffersIfEmpty();
          callback([]);
          return;
        }
        const list: Offer[] = Object.entries(val).map(([id, data]) => {
          const item = data as any;
          return {
            id: item.id || id,
            code: (item.code || id).toUpperCase(),
            title: item.title || 'Special Discount',
            description: item.description || '',
            discountType: item.discountType || 'percentage',
            discountValue: Number(item.discountValue) || 0,
            maxDiscount: item.maxDiscount ? Number(item.maxDiscount) : undefined,
            minBookingAmount: item.minBookingAmount ? Number(item.minBookingAmount) : 0,
            category: item.category || 'all',
            isActive: item.isActive !== false,
            validTill: item.validTill,
            color: item.color || '#7C3AED',
            createdAt: item.createdAt || new Date().toISOString(),
          };
        });
        list.sort((a, b) => new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime());
        callback(list);
      },
      (error) => {
        console.error('Error streaming offers:', error);
        callback([]);
      }
    );
    return () => unsubscribe();
  }

  static async seedInitialOffersIfEmpty(): Promise<void> {
    const offersRef = ref(db, 'offers');
    const snap = await get(offersRef);
    if (!snap.exists()) {
      const initialOffers: Record<string, any> = {
        FIRST50: {
          id: 'FIRST50',
          code: 'FIRST50',
          title: '50% OFF First Booking',
          description: 'Get 50% discount up to ₹100 on your first parking reservation.',
          discountType: 'percentage',
          discountValue: 50,
          maxDiscount: 100,
          minBookingAmount: 50,
          category: 'first_booking',
          isActive: true,
          color: '#7C3AED',
          createdAt: new Date().toISOString(),
        },
        WEEKEND20: {
          id: 'WEEKEND20',
          code: 'WEEKEND20',
          title: '20% OFF Weekend Parking',
          description: 'Save 20% on all Saturday & Sunday parking spot bookings.',
          discountType: 'percentage',
          discountValue: 20,
          maxDiscount: 150,
          minBookingAmount: 100,
          category: 'weekend',
          isActive: true,
          color: '#2563EB',
          createdAt: new Date().toISOString(),
        },
        EVFAST50: {
          id: 'EVFAST50',
          code: 'EVFAST50',
          title: '₹50 Flat OFF EV Charging',
          description: 'Flat ₹50 discount on EV charging enabled parking spaces.',
          discountType: 'flat',
          discountValue: 50,
          minBookingAmount: 150,
          category: 'ev',
          isActive: true,
          color: '#059669',
          createdAt: new Date().toISOString(),
        },
      };
      await set(offersRef, initialOffers);
    }
  }

  static async createOrUpdateOffer(offer: Offer): Promise<void> {
    const offerId = offer.id || offer.code.trim().toUpperCase() || `OFFER_${Date.now()}`;
    const offerRef = ref(db, `offers/${offerId}`);
    await set(offerRef, {
      ...offer,
      id: offerId,
      code: offer.code.trim().toUpperCase(),
      createdAt: offer.createdAt || new Date().toISOString(),
    });
  }

  static async deleteOffer(offerId: string): Promise<void> {
    const offerRef = ref(db, `offers/${offerId}`);
    await set(offerRef, null);
  }

  static async toggleOfferStatus(offerId: string, isActive: boolean): Promise<void> {
    const offerRef = ref(db, `offers/${offerId}`);
    await update(offerRef, { isActive });
  }
}
