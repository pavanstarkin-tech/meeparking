export interface Vehicle {
  id: string;
  number: string;
  model: string;
  type: string; // 'car' | 'bike' | '2-Wheeler' | '4-Wheeler'
}

export interface BankDetails {
  accountNumber?: string;
  ifscCode?: string;
  bankName?: string;
  accountHolderName?: string;
  upiId?: string;
}

export interface UserProfile {
  uid: string;
  name: string;
  email: string;
  phone: string;
  role: 'user' | 'partner' | 'admin';
  photoUrl?: string;
  walletBalance: number;
  fcmToken?: string;
  vehicles?: Vehicle[];
  bankDetails?: BankDetails;
  businessName?: string;
  address?: string;
  status?: 'active' | 'pending' | 'suspended';
  isApproved?: boolean;
  createdAt: string;
}

export interface Booking {
  id: string;
  userId: string;
  spaceId: string;
  partnerId: string;
  spaceTitle: string;
  spaceAddress: string;
  vehicleNumber: string;
  vehicleModel: string;
  vehicleType: string;
  bookingDate: string;
  timeSlot: string;
  durationType?: string;
  totalAmount: number;
  paymentId?: string;
  status: 'upcoming' | 'in-progress' | 'completed' | 'cancelled' | 'confirmed';
  createdAt: string;
  userRating?: number;
  userReview?: string;
}

export interface PricingPlan {
  hourly: number;
  daily: number;
  weekly: number;
  monthly: number;
}

export interface ParkingSpace {
  id: string;
  ownerId: string;
  title: string;
  address: string;
  latitude: number;
  longitude: number;
  pricing: PricingPlan;
  totalSlots: number;
  availableSlots: number;
  isActive: boolean;
  status?: 'approved' | 'pending' | 'rejected';
  images?: string[];
  amenities?: string[];
  isEvCharging?: boolean;
  polygonCoordinates?: number[][];
  totalLandSqMeters?: number;
  createdAt?: string;
}

export interface PayoutRequest {
  id: string;
  partnerId: string;
  partnerName: string;
  partnerEmail?: string;
  partnerPhone?: string;
  amount: number;
  status: 'pending' | 'approved' | 'processed' | 'rejected';
  bankDetails?: BankDetails;
  requestedAt: string;
  processedAt?: string;
  referenceNumber?: string;
  notes?: string;
}

export interface SupportMessage {
  id: string;
  senderId: string;
  senderName: string;
  senderRole: 'user' | 'partner' | 'admin';
  text: string;
  timestamp: string;
}

export interface SupportTicket {
  id: string;
  userId: string;
  userName: string;
  userEmail?: string;
  userPhone?: string;
  userRole?: 'user' | 'partner';
  subject: string;
  description: string;
  category: 'booking' | 'payment' | 'space' | 'account' | 'general';
  status: 'open' | 'in_progress' | 'resolved' | 'closed';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  createdAt: string;
  updatedAt?: string;
  resolutionNotes?: string;
  lastMessage?: string;
  messages?: Record<string, SupportMessage>;
}

export interface WalletTransaction {
  id: string;
  title: string;
  subtitle: string;
  amount: number;
  date: string;
  type: 'credit' | 'debit';
  timestamp: number;
  userId?: string;
}

export interface DashboardMetrics {
  totalRevenue: number;
  totalBookings: number;
  activeBookings: number;
  completedBookings: number;
  cancelledBookings: number;
  totalUsers: number;
  totalPartners: number;
  pendingPartnerApprovals: number;
  totalSpaces: number;
  activeSpaces: number;
  pendingSpaceApprovals: number;
  pendingPayoutsAmount: number;
  openSupportTickets: number;
}

export interface VehicleRateMatrix {
  hourly: number;
  daily: number;
  weekly: number;
  monthly: number;
}

export interface AdminBasePricing {
  twoWheeler: VehicleRateMatrix;
  threeWheeler: VehicleRateMatrix;
  fourWheeler: VehicleRateMatrix;
  updatedAt?: string;
  updatedBy?: string;
}

export interface PartnerApprovalRequest {
  spaceId: string;
  ownerId: string;
  partnerName?: string;
  partnerPhone?: string;
  partnerEmail?: string;
  spaceTitle: string;
  address: string;
  city?: string;
  status: 'pending_approval' | 'approved' | 'rejected';
  totalLandSqMeters?: number;
  maxCars?: number;
  maxBikes?: number;
  images?: string[];
  pricing?: {
    hourly?: number;
    daily?: number;
    weekly?: number;
    monthly?: number;
    twoWheeler?: VehicleRateMatrix;
    threeWheeler?: VehicleRateMatrix;
    fourWheeler?: VehicleRateMatrix;
  };
  submittedAt: string;
  rejectionReason?: string;
}

export interface Offer {
  id: string;
  code: string;
  title: string;
  description: string;
  discountType: 'percentage' | 'flat';
  discountValue: number;
  maxDiscount?: number;
  minBookingAmount?: number;
  category?: 'all' | 'first_booking' | 'weekend' | 'ev';
  isActive: boolean;
  validTill?: string;
  color?: string;
  createdAt?: string;
}
